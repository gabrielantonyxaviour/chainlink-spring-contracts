const email = args[0]
const lastMintTime = args[1]
if (!secrets.accessToken) {
  throw Error("Need to set ACCESS_TOKEN environment variable")
}
const emailRequest = Functions.makeHttpRequest({
  url: "https://www.googleapis.com/userinfo/v2/me",
  method: "GET",
  headers: {
    Authorization: `Bearer ${secrets.accessToken}`,
  },
})

const startTimeRequest = Functions.makeHttpRequest({
  url: "https://riot-rpc-server.adaptable.app/time-util-midnight-timmestamp",
  method: "GET",
})
const [startTimeResponse, emailResponse] = await Promise.all([startTimeRequest, emailRequest])

if (emailResponse.data.email !== email) {
  throw Error("Email does not match")
}

const { startTime: startTimeMillis, endTime: endTimeMillis } = startTimeResponse.data

if (Number(lastMintTime) > startTimeMillis) {
  throw Error("Cannot mint on the same day")
}
// Steps
const stepsRequestBody = {
  aggregateBy: [
    {
      dataTypeName: "com.google.step_count.delta",
      dataSourceId: "derived:com.google.step_count.delta:com.google.android.gms:estimated_steps",
    },
  ],
  bucketByTime: { durationMillis: 86400000 },
  startTimeMillis,
  endTimeMillis,
}

const stepsRequest = Functions.makeHttpRequest({
  url: "https://www.googleapis.com/fitness/v1/users/me/dataset:aggregate",
  method: "POST",
  headers: {
    Authorization: `Bearer ${secrets.accessToken}`,
  },
  data: {
    ...stepsRequestBody,
  },
})

// Calories
const caloriesRequestBody = {
  aggregateBy: [
    {
      dataTypeName: "com.google.calories.expended",
      dataSourceId: "derived:com.google.calories.expended:com.google.android.gms:merge_calories_expended",
    },
  ],
  bucketByTime: { durationMillis: 86400000 },
  startTimeMillis,
  endTimeMillis,
}

const caloriesRequest = Functions.makeHttpRequest({
  url: "https://www.googleapis.com/fitness/v1/users/me/dataset:aggregate",
  method: "POST",
  headers: {
    Authorization: `Bearer ${secrets.accessToken}`,
    "Content-Type": "application/json",
  },
  data: {
    ...caloriesRequestBody,
  },
})

// Heart Points
const heartPointsRequestBody = {
  aggregateBy: [
    {
      dataTypeName: "com.google.heart_minutes",
      dataSourceId: "derived:com.google.heart_minutes:com.google.android.gms:merge_heart_minutes",
    },
  ],
  bucketByTime: { durationMillis: 86400000 },
  startTimeMillis,
  endTimeMillis,
}
const heartPointsRequest = Functions.makeHttpRequest({
  url: "https://www.googleapis.com/fitness/v1/users/me/dataset:aggregate",
  method: "POST",
  headers: {
    Authorization: `Bearer ${secrets.accessToken}`,
    "Content-Type": "application/json",
  },
  data: {
    ...heartPointsRequestBody,
  },
})
const [stepsResponse, caloriesResponse, HeartPointsResponse] = await Promise.all([
  stepsRequest,
  caloriesRequest,
  heartPointsRequest,
])
let steps = 0
let calories = 0
let heartPoints = 0
if (!stepsResponse.error) {
  console.log("Steps response", stepsResponse)
  const stepCountData = stepsResponse.data
  if (stepCountData.bucket && stepCountData.bucket.length > 0) {
    steps = stepCountData.bucket.reduce((totalSteps, bucket) => {
      return (
        totalSteps +
        bucket.dataset[0].point.reduce((bucketSteps, point) => {
          return bucketSteps + point.value[0].intVal
        }, 0)
      )
    }, 0)
  }
}
if (!caloriesResponse.error) {
  console.log("Calories response", caloriesResponse)
  const caloriesData = caloriesResponse.data
  if (caloriesData.bucket && caloriesData.bucket.length > 0) {
    calories = caloriesData.bucket.reduce((totalCalories, bucket) => {
      return (
        totalCalories +
        bucket.dataset[0].point.reduce((bucketCalories, point) => {
          return bucketCalories + point.value[0].fpVal
        }, 0)
      )
    }, 0)
  }
}
if (!HeartPointsResponse.error) {
  console.log("Heart Points response", HeartPointsResponse)
  const heartPointsData = HeartPointsResponse.data
  if (heartPointsData.bucket && heartPointsData.bucket.length > 0) {
    heartPoints = heartPointsData.bucket.reduce((totalHeartPoints, bucket) => {
      return (
        totalHeartPoints +
        bucket.dataset[0].point.reduce((bucketHeartPoints, point) => {
          return bucketHeartPoints + point.value[0].fpVal
        }, 0)
      )
    }, 0)
  }
}
console.log("Steps", steps)
console.log("Calories", calories)
console.log("Heart Points", heartPoints)
const MAX_HEART_POINTS = 100
const MAX_CALORIES_BURNT = 5000
const MAX_TOTAL_STEPS = 10000

const WEIGHT_HEART_POINTS = 0.5
const WEIGHT_CALORIES_BURNT = 0.3
const WEIGHT_TOTAL_STEPS = 0.2

const normalizedHeartPoints = heartPoints / MAX_HEART_POINTS
const normalizedCaloriesBurnt = calories / MAX_CALORIES_BURNT
const normalizedTotalSteps = steps / MAX_TOTAL_STEPS

// Calculate the weighted scores
const weightedHeartPoints = normalizedHeartPoints * WEIGHT_HEART_POINTS
const weightedCaloriesBurnt = normalizedCaloriesBurnt * WEIGHT_CALORIES_BURNT
const weightedTotalSteps = normalizedTotalSteps * WEIGHT_TOTAL_STEPS

// Calculate the overall weighted score
const overallWeightedScore = weightedHeartPoints + weightedCaloriesBurnt + weightedTotalSteps

// Define the desired token minting range
const minTokens = 0
const maxTokens = 1000

// Map the overall weighted score to the desired token minting range
const tokenMinting = overallWeightedScore * (maxTokens - minTokens) + minTokens

// Round the token minting to the nearest integer
const result = Math.round(tokenMinting)

console.log("Tokens minted:", result)

return Functions.encodeUint256(result)
