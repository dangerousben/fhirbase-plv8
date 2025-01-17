utils = require('../core/utils')
compat = require('../compat')
fhirVersion = require('./fhir_version')
fhirbaseVersion = require('../core/fhirbase_version')

exports.fhir_conformance = (plv8, base)->
  base.resourceType = 'Conformance'
  base.acceptUnknown = true

  base.fhirVersion = base.fhirVersion || fhirVersion.fhir_version()
  base.version =  base.version || fhirbaseVersion.fhirbase_version()

  base.software = {
    name: 'Fhirbase'
    releaseDate: base.releaseDate || fhirbaseVersion.fhirbase_release_date()
    version: base.version || fhirbaseVersion.fhirbase_version()
  }

  schema = utils.current_schema(plv8)


  tables = utils.exec plv8,
    select: ':*'
    from: ':pg_tables'
    where: ['$and',
      ['$eq', ':schemaname', schema]
      ['$ilike', ':tablename', "%_history"]]

  resources = tables.map((x)-> x.tablename.replace('_history', ''))

  profiles = utils.exec(plv8,
    select: ':*'
    from: ':structuredefinition'
    where: ['$in', ':lower(id)', resources]
  ).map((x)-> compat.parse(plv8, x.resource))

  base.rest = [
    mode: 'server'
    resource: profiles.map (p)->
      type: p.name
      versioning: 'versioned'
      profile:
        reference:  "/fhir/StructureDefinition/#{p.name}"
      interaction: ["read","vread","update","delete","history-instance","validate","history-type","create","search-type"].map((tp)-> {code: tp})
  ]
  base


exports.fhir_conformance.plv8_signature = ['json', 'json']
