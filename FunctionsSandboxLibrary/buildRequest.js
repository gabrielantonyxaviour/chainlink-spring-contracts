"use strict"
Object.defineProperty(exports, "__esModule", { value: true })
exports.buildRequest = void 0
const getRequestConfig_1 = require("./getRequestConfig")
const encryptSecrets_1 = require("./encryptSecrets")
const buildRequest = async (unvalidatedConfig) => {
  const config = (0, getRequestConfig_1.getRequestConfig)(unvalidatedConfig)
  const request = { source: config.source }
  console.log("Now we are inside the buildRequest function after uploading in Github\n")
  console.log(config)

  if (config.secretsURLs && config.secretsURLs.length > 0) {
    console.log(config.secretsURLs.join(" "))
    console.log("We are encrypting the secrets again\n")
    request.secrets = "0x" + (await (0, encryptSecrets_1.encrypt)(config.DONPublicKey, config.secretsURLs.join(" ")))
  }
  if (config.args) {
    request.args = config.args
  }

  return request
}
exports.buildRequest = buildRequest
