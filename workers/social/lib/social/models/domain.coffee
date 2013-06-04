jraphical = require 'jraphical'
DomainManager = require 'domainer'

module.exports = class JDomain extends jraphical.Module
  {secure}  = require 'bongo'

  domainManager = new DomainManager
  JAccount  = require './account'
  JVM       = require './vm'

  @share()

  @set
    softDelete      : yes

    sharedMethods   :
      static        : ['one', 'all', 'count', 'createDomain', 'findByAccount', 'fetchByDomain', 'fetchByUserId', 
                       'isDomainAvailable','addNewDNSRecord', 'removeDNSRecord', 'registerDomain']

    indexes         :
      domain        : 'unique'

    schema          :
      domain        :
        type        : String
        validate    : (value)-> !!value
        set         : (value)-> value.toLowerCase()
      rcOrderId     : Number
      recOrderId    : Number
      owner         : JAccount
      vms           : [JVM]
      createdAt     :
        type        : Date
        default     : -> new Date
      modifiedAt    :
        type        : Date
        default     : -> new Date

  @createDomain: (options={}, callback)->
    model = new JDomain options
    model.save (err) ->
      callback? err, model

  @findByAccount: secure (client, selector, callback)->
    @all selector, (err, domains) ->
      if err then warn err
      domainList = ({name:domain.domain, id:domain.getId(), vms:domain.vms} for domain in domains)
      callback? err, domainList

  @fetchAll = secure ({connection:{delegate}}, callback)->
    JDomain.all
      owner : delegate.getId()
    , (err, domains)->
      callback err, domains


  @fetchByDomain = secure ({connection:{delegate}}, options, callback)->
    JDomain.one
      domain   : options.domain
    , (err, domain)->
      callback err, domain


  @fetchByUserId = secure ({connection:{delegate}}, callback)->
    JDomain.all
      owner : delegate.getId()
    , (err, domains)->
      callback err, domains
 

  @isDomainAvailable = (domainName, tld, callback)->
    domainManager.domainService.isDomainAvailable domainName, tld, (err, isAvailable)->
      callback err, isAvailable
  
  @registerDomain = secure ({connection:{delegate}}, data, callback)->
    #default user info / all domains are under koding account.
    params =
      "domainName"         : data.domainName
      "years"              : data.years
      "customerId"         : "9663202"
      "regContactId"       : "28083911"
      "adminContactId"     : "28083911"
      "techContactId"      : "28083911"
      "billingContactId"   : "28083911"
      "invoiceOption"      : "NoInvoice"
      "protectPrivacy"     : no
      # "linkedVM"           : data.selectedVM


    domainManager.domainService.registerDomain params, (err, data)=>
      if err then return callback err, data

      domainOrder = 
        domain       : data.description
        orderId      : data.entityid
        linkURL      : data.description
        #linkedVM     : params.linkedVM

      if data.actionstatus is "Success"
        @create delegate, domainOrder, (err, record) =>
          callback null, record
      else
          callback {error:"Domain registration failed"}, null


  @addNewDNSRecord = secure ({connection:{delegate}}, data, callback)->
    newRecord = 
      mode          : "vm"
      username      : delegate.profile.nickname
      domainName : data.domainName
      linkedVM      : data.selectedVM

    domainManager.dnsManager.registerNewRecordToProxy newRecord, (response)=>
      domain = 
        domain       : newRecord.domainName
        orderId      : "0" # when forwarding we got no orderid
        linkURL      : newRecord.domainName
        linkedVM     : newRecord.linkedVM

      @create delegate,domain, (err, record) =>
        callback null, record


  @removeDNSRecord = secure ({connection:{delegate}}, data, callback)->
    record =
      username      : client.context.user
      domainName : data.domainName
      mode          : "vm"
     
    # not working should talk with farslan
    domainManager.dnsManager.removeDNSRecordFromProxy record, (response)->
      callback response
     


  @addVMAccessRule = secure (client, data, callback) ->
    #not implemented yet

  @removeVMAccessRule = secure (client, data, callback) ->
    #not implemented yet

  @listVMAccessRules = secure (client, data, callback) ->
    #not implemented yet

  @getDomainDetails = secure (client, data, callback) ->
    #not implemented yet

  @updateDomainContacts = secure (client, data, callback) ->
    #not implemented yet

  @createCustomerContact = secure (client, data, callback) ->
    #not implemented yet

  @updateCustımerContact = secure (client, data, callback) ->
    #not implemented yet