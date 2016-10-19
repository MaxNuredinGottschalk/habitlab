{
  polymer_ext
  list_polymer_ext_tags_with_info
} = require 'libs_frontend/polymer_utils'

{
  get_enabled_goals
  get_goals
  get_goal_target
} = require 'libs_backend/goal_utils'

{
  get_progress_on_goals_this_week
} = require 'libs_backend/goal_progress'

{
  goal_success_on_date
} = require 'libs_common/goal_success'

{cfy} = require 'cfy'

require! {
  async
}

require! {
  prelude
}

$ = require 'jquery'

polymer_ext {
  is: 'goals-met-over-time'
  properties: {
  }
  ready: cfy ->*
    self = this
    last_week = [] /* success rates for the last week */
    var today = moment()
    for day from 0 to 6
      var day = today.subtract(day, 'days')
      var success_object = goal_success_on_date(day)
      last_week.push(success_object)

    # Now we add it to the visualization

}
