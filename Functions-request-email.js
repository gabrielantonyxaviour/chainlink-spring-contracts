if (!secrets.accessToken) {
  throw Error("Need to set ACCESS_TOKEN environment variable")
}
console.log(secrets.accessToken)
const emailRequest = Functions.makeHttpRequest({
  url: "https://www.googleapis.com/userinfo/v2/me",
  method: "GET",
  headers: {
    Authorization: `Bearer ${secrets.accessToken}`,
  },
})

const [emailResponse] = await Promise.all([emailRequest])
console.log(emailResponse)
if (!emailResponse.error) {
  const result = emailResponse.data.email
  return Functions.encodeString(result)
} else {
  throw Error("Error getting email")
}
