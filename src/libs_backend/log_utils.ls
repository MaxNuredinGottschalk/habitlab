{
  memoize
  memoizeSingleAsync
} = require 'libs_common/memoize'

{
  gexport
  gexport_module
} = require 'libs_common/gexport'

{
  get_days_since_epoch
} = require 'libs_common/time_utils'

{
  get_user_id
} = require 'libs_backend/background_common'

{
  sleep
} = require 'libs_frontend/common_libs'

require! {
  dexie
}

{generate_random_id} = require 'libs_common/generate_random_id'

{cfy} = require 'cfy'

chrome_manifest = chrome.runtime.getManifest()
habitlab_version = chrome_manifest.version
developer_mode = not chrome_manifest.update_url?
unofficial_version = chrome.runtime.id != 'obghclocpdgcekcognpkblghkedcpdgd'

export get_db_major_version_interventionlogdb = -> '8'
export get_db_minor_version_interventionlogdb = -> '1'

export delete_db_if_outdated_interventionlogdb = cfy ->*
  if localStorage.getItem('db_minor_version_interventionlogdb') != get_db_minor_version_interventionlogdb()
    localStorage.setItem('db_minor_version_interventionlogdb', get_db_minor_version_interventionlogdb())
  if localStorage.getItem('db_major_version_interventionlogdb') != get_db_major_version_interventionlogdb()
    yield deleteInterventionLogDb()
    localStorage.removeItem('current_schema_interventionlogdb')
    localStorage.setItem('db_major_version_interventionlogdb', get_db_major_version_interventionlogdb())
  return

export get_current_schema_interventionlogdb = ->
  result = localStorage.getItem('current_schema_interventionlogdb')
  if not result?
    return {}
  return JSON.parse result

export get_current_dbver_interventionlogdb = ->
  result = localStorage.getItem('current_dbver_interventionlogdb')
  if not result?
    return 0
  return parseInt result

export get_interventions_seen_today = cfy ->*
  interventions = yield intervention_utils.list_all_interventions()
  enabled = yield intervention_utils.get_enabled_interventions()
  invns = []
  for intervention in interventions #get interventions seen today
    result = yield get_num_impressions_today(intervention)
    if result > 0
      invns.push intervention
  for key in Object.keys(enabled) #filter for enabled interventions
    if enabled[key] == false
      delete enabled[key]
  combined = Array.from(new Set(invns.concat(enabled))) #remove duplicates
  combined.pop()
  return combined

  

export get_log_names = cfy ->*
  interventions_list = yield intervention_utils.list_all_interventions()
  logs_list = ['goals', 'interventions', 'feedback'].map -> 'logs/'+it
  return interventions_list.concat(logs_list)

intervention_logdb_cache = null

export clear_intervention_logdb_cache = ->
  if intervention_logdb_cache?
    intervention_logdb_cache.close()
  intervention_logdb_cache := null

export getInterventionLogDb = cfy ->*
  if intervention_logdb_cache?
    return intervention_logdb_cache
  output = yield getInterventionLogDb_uncached()
  intervention_logdb_cache := output
  return intervention_logdb_cache

getInterventionLogDb_uncached = cfy ->*
  yield delete_db_if_outdated_interventionlogdb()
  log_names = yield get_log_names()
  db = new dexie('interventionlog', {autoOpen: false})
  dbver = get_current_dbver_interventionlogdb()
  prev_schema = get_current_schema_interventionlogdb()
  stores_to_create = {}
  for logname in log_names
    if not prev_schema[logname]?
      stores_to_create[logname] = '++id,[type+day],type,day,itemid,synced'
  new_schema = {[k,v] for k,v of prev_schema}
  if Object.keys(stores_to_create).length > 0
    db.version(dbver).stores(prev_schema)
    dbver += 1
    for k,v of stores_to_create
      new_schema[k] = v
    db.on 'ready', ->
      localStorage.setItem 'current_schema_interventionlogdb', JSON.stringify(new_schema)
      localStorage.setItem 'current_dbver_interventionlogdb', dbver
    db.on 'versionchange', ->
      intervention_logdb_cache := null
      db.close()
      intervention_logdb_cache := null
  db.version(dbver).stores(new_schema)
  realdb = yield db.open()
  return realdb

export deleteInterventionLogDb = cfy ->*
  console.log 'deleteInterventionLogDb called'
  localStorage.removeItem('current_schema_interventionlogdb')
  localStorage.removeItem('current_dbver_interventionlogdb')
  db = new dexie('interventionlog')
  yield db.delete()
  return

export getInterventionLogCollection = cfy (name) ->*
  db = yield getInterventionLogDb()
  return db[name]

export add_log_goals = cfy (data) ->*
  data = {} <<< data
  if not data.enabled_interventions?
    data.enabled_interventions = yield intervention_utils.get_enabled_interventions()
  if not data.enabled_goals?
    data.enabled_goals = yield goal_utils.get_enabled_goals()
  yield addtolog 'logs/goals', data

export add_log_interventions = cfy (data) ->*
  data = {} <<< data
  if not data.enabled_interventions?
    data.enabled_interventions = yield intervention_utils.get_enabled_interventions()
  if not data.enabled_goals?
    data.enabled_goals = yield goal_utils.get_enabled_goals()
  yield addtolog 'logs/interventions', data

export add_log_feedback = cfy (data) ->*
  data = {} <<< data
  if not data.enabled_interventions?
    data.enabled_interventions = yield intervention_utils.get_enabled_interventions()
  if not data.enabled_goals?
    data.enabled_goals = yield goal_utils.get_enabled_goals()
  yield addtolog 'logs/feedback', data

export addtolog = cfy (name, data) ->*
  data = {} <<< data
  if not data.type?
    data.type = 'general'
  data.userid = yield get_user_id()
  data.day = get_days_since_epoch()
  data.synced = 0
  data.timestamp = Date.now()
  data.localtime = new Date().toString()
  data.itemid = generate_random_id()
  data.log_major_ver = get_db_major_version_interventionlogdb()
  data.log_minor_ver = get_db_minor_version_interventionlogdb()
  data.habitlab_version = habitlab_version
  if developer_mode
    data.developer_mode = true
  if unofficial_version
    data.unofficial_version = chrome.runtime.id
  collection = yield getInterventionLogCollection(name)
  result = yield collection.add(data)
  return data

export getlog = cfy (name) ->*
  collection = yield getInterventionLogCollection(name)
  result = yield collection.toArray()
  return result

export clearlog = cfy (name) ->*
  collection = yield getInterventionLogCollection(name)
  num_deleted = yield collection.delete()
  return

export get_num_impressions = cfy (name) ->*
  collection = yield getInterventionLogCollection(name)
  num_impressions = yield collection.where('type').equals('impression').count()
  return num_impressions

export get_num_impressions_for_days_since_today = cfy (name, days_since_today) ->*
  collection = yield getInterventionLogCollection(name)
  day = get_days_since_epoch() - days_since_today
  num_impressions = yield collection.where('[type+day]').equals(['impression', day]).count()
  return num_impressions

export get_num_impressions_today = cfy (name) ->*
  yield get_num_impressions_for_days_since_today name, 0

export get_num_actions = cfy (name) ->*
  collection = yield getInterventionLogCollection(name)
  num_actions = yield collection.where('type').equals('action').count()
  return num_actions

export get_num_actions_for_days_since_today = cfy (name, days_since_today) ->*
  collection = yield getInterventionLogCollection(name)
  day = get_days_since_epoch() - days_since_today
  num_actions = yield collection.where('[type+day]').equals(['action', day]).count()
  return num_actions

export get_num_actions_today = cfy (name) ->*
  yield get_num_actions_for_days_since_today name, 0

export get_num_actions = cfy (name) ->*
  collection = yield getInterventionLogCollection(name)
  day = get_days_since_epoch()
  num_actions = yield collection.where('[type+day]').equals(['action', day]).count()
  return num_actions

export log_impression_internal = cfy (name, data) ->*
  # name = intervention name
  # ex: facebook/notification_hijacker
  if data?
    data = {} <<< data
  else
    data = {}
  data.type = 'impression'
  data.intervention = name
  yield addtolog name, data

export log_disable_internal = cfy (name, data) ->*
  # name = intervention name
  # ex: facebook/notification_hijacker
  if data?
    data = {} <<< data
  else
    data = {}
  data.type = 'disable'
  data.intervention = name
  yield addtolog name, data

export log_action_internal = cfy (name, data) ->*
  # name = intervention name
  # ex: facebook/notification_hijacker
  # data: a dictionary containing any details necessary
  # ex: {}
  if data?
    data = {} <<< data
  else
    data = {}
  data.type = 'action'
  data.intervention = name
  yield addtolog name, data

intervention_utils = require 'libs_backend/intervention_utils'
goal_utils = require 'libs_backend/goal_utils'

gexport_module 'log_utils_backend', -> eval(it)
