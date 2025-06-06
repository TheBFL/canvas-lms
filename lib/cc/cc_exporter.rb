# frozen_string_literal: true

#
# Copyright (C) 2011 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

module CC
  class CCExporter
    include TextHelper

    ZIP_DIR = "zip_dir"

    attr_accessor :course, :user, :export_dir, :manifest, :zip_file, :for_course_copy, :for_master_migration, :disable_content_rewriting

    delegate :add_error, :add_item_to_export, to: :@content_export, allow_nil: true

    def initialize(content_export, opts = {})
      @content_export = content_export
      @course = opts[:course] || @content_export.context
      raise "CCExporter supports only Courses" unless @course.is_a?(Course) # a Course is a Course, of course, of course

      @disable_content_rewriting = @content_export&.disable_content_rewriting?
      @user = opts[:user] || @content_export.user
      @export_dir = nil
      @manifest = nil
      @zip_file = nil
      @zip_name = nil
      @logger = Rails.logger
      @migration_config = ConfigFile.load("external_migration")
      @migration_config ||= { keep_after_complete: false }
      @for_course_copy = opts[:for_course_copy]
      @qti_only_export = @content_export&.qti_export?
      @manifest_opts = opts.slice(:version)
      @deletions = opts[:deletions]

      @for_master_migration = true if @content_export&.for_master_migration?
    end

    def self.export(content_export, opts = {})
      exporter = CCExporter.new(content_export, opts)
      exporter.export
    end

    def export
      begin
        if for_external_migration? && !@content_export.selective_export?
          # we already know we're exporting all the data so we can begin the external exports now
          @pending_exports = Canvas::Migration::ExternalContent::Migrator.begin_exports(@course,
                                                                                        @content_export)
        end

        create_export_dir
        create_zip_file
        @manifest = if @qti_only_export
                      CC::Qti::QtiManifest.new(self)
                    else
                      Manifest.new(self, @manifest_opts)
                    end
        @manifest.create_document
        @manifest.close

        if for_external_migration?
          if @content_export.selective_export?
            # if it's selective, we have to wait until we've completed the rest of the export
            # before we really know what we exported. because magic
            @pending_exports = Canvas::Migration::ExternalContent::Migrator.begin_exports(@course,
                                                                                          @content_export,
                                                                                          selective: true,
                                                                                          exported_assets: @content_export.exported_assets.to_a)
          end
          external_content = Canvas::Migration::ExternalContent::Migrator.retrieve_exported_content(@content_export, @pending_exports)
          write_external_content(external_content)
        end

        @export_dirs = [@export_dir]
        if @for_master_migration || @content_export&.for_course_template?
          # for efficiency to the max, short-circuit the usual course copy process (i.e. zip up, save, and then unzip again)
          # and instead go straight to the intermediate json
          converter = CC::Importer::Canvas::Converter.new(
            unzipped_file_path: @export_dir,
            deletions: @deletions,
            is_discussion_checkpoints_enabled: discussion_checkpoints_enabled?
          )
          @export_dirs << converter.base_export_dir # make sure we clean this up too afterwards
          converter.export
          @export_path = converter.course["full_export_file_path"] # this is the course_export.json
          @export_type = "application/json"
        else
          copy_all_to_zip
          @zip_file.close
          @export_path = @zip_path
        end

        if @content_export && File.exist?(@export_path)
          att = Attachment.new
          att.context = @content_export
          att.user = @content_export.user
          data = Canvas::UploadedFile.new(@export_path, @export_type || Attachment.mimetype(@export_path))
          Attachments::Storage.store_for_attachment(att, data)
          if att.save
            @content_export.attachment = att
            @content_export.save
          end
        end
      rescue
        add_error(I18n.t("course_exports.errors.course_export", "Error running course export."), $!)
        @logger.error $!
        return false
      ensure
        @zip_file&.close
        unless @migration_config[:keep_after_complete]
          @export_dirs&.each do |export_dir|
            FileUtils.rm_rf(export_dir) if File.directory?(export_dir)
          end
        end
      end
      true
    end

    def write_external_content(external_content)
      return unless external_content.present?

      folder = File.join(@export_dir, CCHelper::EXTERNAL_CONTENT_FOLDER)
      FileUtils.mkdir_p(folder)

      external_content.each do |service_key, data|
        path = File.join(folder, "#{service_key}.json")
        File.write(path, data.to_json)
      end
    end

    def referenced_files
      @manifest ? @manifest.referenced_files : {}
    end

    def set_progress(progress)
      @content_export&.fast_update_progress(progress)
    end

    def errors
      @content_export ? @content_export.error_messages : []
    end

    def export_id
      @content_export&.id
    end

    def create_key(*)
      @content_export ? @content_export.create_key(*) : CCHelper.create_key(*)
    end

    def export_object?(obj, asset_type: nil, ignore_updated_at: false)
      @content_export ? @content_export.export_object?(obj, asset_type:, ignore_updated_at:) : true
    end

    def add_exported_asset(obj)
      @content_export&.add_exported_asset(obj)
    end

    def export_symbol?(obj)
      @content_export ? @content_export.export_symbol?(obj) : true
    end

    def epub_export?
      @content_export ? @content_export.epub_export.present? : false
    end

    def for_external_migration?
      @content_export && !(@qti_only_export || epub_export?)
    end

    delegate :include_new_quizzes_in_export?, to: :@content_export

    def new_quizzes_export_url
      @content_export.settings[:new_quizzes_export_url]
    end

    delegate :common_cartridge?, to: :@content_export

    private

    def discussion_checkpoints_enabled?
      @content_export&.context&.discussion_checkpoints_enabled? || false
    end

    def copy_all_to_zip
      Dir["#{@export_dir}/**/**"].each do |file|
        file_path = file.sub(@export_dir + "/", "")
        next if file_path.starts_with? ZIP_DIR

        unless @zip_file.find_entry(file_path)
          @zip_file.add(file_path, file)
        end
      end
    end

    def create_export_dir
      slug = "common_cartridge_#{@course.id}"
      slug << "_user_#{@user.id}" if @user
      folder = @migration_config[:data_folder] || Dir.tmpdir

      @export_dir = File.join(folder, slug)
      i = 1
      while File.exist?(@export_dir) && File.directory?(@export_dir)
        i += 1
        @export_dir = File.join(folder, "#{slug}_attempt_#{i}")
      end

      FileUtils.mkdir_p @export_dir
      @export_dir
    end

    def create_zip_file
      name = CanvasTextHelper.truncate_text(@course.name.to_url, { max_length: 200, ellipsis: "" })
      @zip_name = if @qti_only_export
                    "#{name}-quiz-export.zip"
                  else
                    "#{name}-export.#{CCHelper::CC_EXTENSION}"
                  end
      FileUtils.mkdir_p File.join(@export_dir, ZIP_DIR)
      @zip_path = File.join(@export_dir, ZIP_DIR, @zip_name)
      @zip_file = Zip::File.new(@zip_path, Zip::File::CREATE)
    end
  end
end
