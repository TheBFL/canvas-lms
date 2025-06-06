/*
 * Copyright (C) 2016 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import React from 'react'
import PropTypes from 'prop-types'
import {Button} from '@instructure/ui-buttons'
import {Checkbox} from '@instructure/ui-checkbox'
import {useScope as createI18nScope} from '@canvas/i18n'
import setsApi from '@canvas/grading/jquery/gradingPeriodSetsApi'
import EnrollmentTermInput from './EnrollmentTermInput'
import {showFlashAlert} from '@canvas/alerts/react/FlashAlert'

const I18n = createI18nScope('NewGradingPeriodSetForm')

export default class NewGradingPeriodSetForm extends React.Component {
  static propTypes = {
    enrollmentTerms: PropTypes.array.isRequired,
    closeForm: PropTypes.func.isRequired,
    addGradingPeriodSet: PropTypes.func.isRequired,
    urls: PropTypes.shape({
      gradingPeriodSetsURL: PropTypes.string.isRequired,
    }).isRequired,
  }

  constructor(props) {
    super(props)
    this.titleInput = React.createRef()
    this.cancelButton = React.createRef()
    this.createButton = React.createRef()
    
    this.state = {
      buttonsDisabled: false,
      title: '',
      weighted: false,
      displayTotalsForAllGradingPeriods: false,
      selectedEnrollmentTermIDs: [],
    }
  }

  componentDidMount() {
    this.titleInput.current.focus()
  }

  setSelectedEnrollmentTermIDs = termIDs => {
    this.setState({
      selectedEnrollmentTermIDs: termIDs,
    })
  }

  isTitlePresent = () => {
    if (this.state.title.trim() !== '') {
      return true
    } else {
      showFlashAlert({type: 'error', message: I18n.t('A name for this set is required')})
      return false
    }
  }

  isValid = () => this.isTitlePresent()

  submit = event => {
    event.preventDefault()
    this.setState({buttonsDisabled: true}, () => {
      if (this.isValid()) {
        const set = {
          title: this.state.title.trim(),
          weighted: this.state.weighted,
          displayTotalsForAllGradingPeriods: this.state.displayTotalsForAllGradingPeriods,
          enrollmentTermIDs: this.state.selectedEnrollmentTermIDs,
        }
        setsApi.create(set).then(this.submitSucceeded).catch(this.submitFailed)
      } else {
        this.setState({buttonsDisabled: false})
      }
    })
  }

  submitSucceeded = set => {
    showFlashAlert({type: 'success', message: I18n.t('Successfully created a set')})
    this.props.addGradingPeriodSet(set, this.state.selectedEnrollmentTermIDs)
  }

  submitFailed = () => {
    showFlashAlert({type: 'error', message: I18n.t('There was a problem submitting your set')})
    this.setState({buttonsDisabled: false})
  }

  onSetTitleChange = event => {
    this.setState({title: event.target.value})
  }

  onSetWeightedChange = event => {
    this.setState({weighted: event.target.checked})
  }

  onSetDisplayTotalsChanged = event => {
    this.setState({displayTotalsForAllGradingPeriods: event.target.checked})
  }

  render() {
    return (
      <div className="GradingPeriodSetForm pad-box">
        <form className="ic-Form-group ic-Form-group--horizontal">
          <div className="grid-row">
            <div className="col-xs-12 col-lg-6">
              <div className="ic-Form-control">
                <label htmlFor="set-name" className="ic-Label">
                  {I18n.t('Set name')}
                </label>
                <input
                  onChange={this.onSetTitleChange}
                  type="text"
                  id="set-name"
                  className="ic-Input"
                  placeholder={I18n.t('Set name...')}
                  ref={this.titleInput}
                />
              </div>
              <EnrollmentTermInput
                enrollmentTerms={this.props.enrollmentTerms}
                selectedIDs={this.state.selectedEnrollmentTermIDs}
                setSelectedEnrollmentTermIDs={this.setSelectedEnrollmentTermIDs}
              />
              <div className="ic-Input pad-box top-only">
                <Checkbox
                  ref={ref => {
                    this.weightedCheckbox = ref
                  }}
                  label={I18n.t('Weighted grading periods')}
                  value="weighted"
                  checked={this.state.weighted}
                  onChange={this.onSetWeightedChange}
                />
              </div>
              <div className="ic-Input pad-box top-only">
                <Checkbox
                  ref={ref => {
                    this.displayTotalsCheckbox = ref
                  }}
                  label={I18n.t('Display totals for All Grading Periods option')}
                  value="totals"
                  checked={this.state.displayTotalsForAllGradingPeriods}
                  onChange={this.onSetDisplayTotalsChanged}
                />
              </div>
            </div>
          </div>
          <div className="grid-row">
            <div className="col-xs-12 col-lg-12">
              <div className="ic-Form-actions below-line">
                <Button
                  disabled={this.state.buttonsDisabled}
                  onClick={this.props.closeForm}
                  ref={this.cancelButton}
                >
                  {I18n.t('Cancel')}
                </Button>
                &nbsp;
                <Button
                  disabled={this.state.buttonsDisabled}
                  color="primary"
                  onClick={this.submit}
                  ref={this.createButton}
                >
                  {I18n.t('Create')}
                </Button>
              </div>
            </div>
          </div>
        </form>
      </div>
    )
  }
}
