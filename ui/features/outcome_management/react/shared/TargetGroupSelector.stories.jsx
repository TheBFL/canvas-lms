/*
 * Copyright (C) 2021 - present Instructure, Inc.
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
import {MockedProvider} from '@apollo/client/testing'
import {createCache} from '@canvas/apollo-v3'
import TargetGroupSelector from './TargetGroupSelector'
import OutcomesContext from '@canvas/outcomes/react/contexts/OutcomesContext'
import {smallOutcomeTree, moveOutcomeMock} from '@canvas/outcomes/mocks/Management'

export default {
  title: 'Examples/Outcomes/TargetGroupSelector',
  component: TargetGroupSelector,
  args: {
    groupId: '2',
    parentGroupId: '1',
    setTargetGroup: () => {},
    modalName: 'groupMoveModal',
  },
}

const Template = args => (
  <OutcomesContext.Provider
    value={{env: {contextType: 'Account', contextId: '1', rootOutcomeGroup: {id: '100'}}}}
  >
    <MockedProvider mocks={[...smallOutcomeTree(), moveOutcomeMock()]} cache={createCache()}>
      <TargetGroupSelector {...args} />
    </MockedProvider>
  </OutcomesContext.Provider>
)
export const Default = Template.bind({})
