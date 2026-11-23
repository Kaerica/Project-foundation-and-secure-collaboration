const http = require('node:http')
const { createProductStore } = require('./database')

const PORT = Number(process.env.PORT) || 3000
const MAX_BODY_BYTES = 1024 * 1024

function createServer ({ productStore = createProductStore() } = {}) {
  return http.createServer((request, response) => {
    response.setHeader('Content-Type', 'application/json; charset=utf-8')
    handleRequest(request, response, productStore).catch((error) => {
      const clientError = getClientError(error)

      if (clientError) {
        sendJson(response, clientError.statusCode, { error: clientError.message })
        return
      }

      console.error('Request failed:', error)
      sendJson(response, 500, { error: 'Internal server error.' })
    })
  })
}

async function handleRequest (request, response, productStore) {
  if (request.method === 'GET' && request.url === '/health') {
    try {
      await productStore.checkConnection()
      sendJson(response, 200, { status: 'ok' })
    } catch (error) {
      sendJson(response, 503, { status: 'error', error: 'Database unavailable.' })
    }
    return
  }

  if (request.method === 'GET' && request.url === '/') {
    sendJson(response, 200, { products: await productStore.listProducts() })
    return
  }

  if (request.method === 'GET' && request.url === '/products/low-stock') {
    sendJson(response, 200, { products: await productStore.getLowStockProducts() })
    return
  }

  if (request.method === 'POST' && request.url === '/products') {
    const body = await readJsonBody(request)
    const product = await productStore.addProduct(body.name, body.price, body.quantity)
    sendJson(response, 201, { product })
    return
  }

  const quantityRoute = request.url.match(/^\/products\/(\d+)\/quantity$/)
  if (request.method === 'PATCH' && quantityRoute) {
    const body = await readJsonBody(request)
    const message = await productStore.updateQuantity(
      Number(quantityRoute[1]),
      body.quantity
    )
    sendJson(response, 200, { message })
    return
  }

  sendJson(response, 404, { error: 'Not found.' })
}

function readJsonBody (request) {
  return new Promise((resolve, reject) => {
    let body = ''
    let tooLarge = false

    request.setEncoding('utf8')
    request.on('data', (chunk) => {
      if (tooLarge) return

      body += chunk
      if (Buffer.byteLength(body, 'utf8') > MAX_BODY_BYTES) {
        tooLarge = true
        body = ''
      }
    })
    request.on('end', () => {
      if (tooLarge) {
        reject(createRequestError(413, 'Request body is too large.'))
        return
      }

      try {
        const parsed = JSON.parse(body)
        if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
          throw new Error('Request body must be a JSON object.')
        }
        resolve(parsed)
      } catch {
        reject(createRequestError(400, 'Request body must be a valid JSON object.'))
      }
    })
    request.on('error', reject)
  })
}

function createRequestError (statusCode, message) {
  const error = new Error(message)
  error.statusCode = statusCode
  return error
}

function getClientError (error) {
  if (error.statusCode) {
    return { statusCode: error.statusCode, message: error.message }
  }

  if (error.message === 'Product not found.') {
    return { statusCode: 404, message: error.message }
  }

  if ([
    'Product name must not be empty.',
    'Price must be a non-negative number.',
    'Quantity must be a non-negative whole number.'
  ].includes(error.message)) {
    return { statusCode: 400, message: error.message }
  }

  return null
}

function sendJson (response, statusCode, body) {
  response.statusCode = statusCode
  response.end(JSON.stringify(body))
}

async function startServer () {
  const productStore = createProductStore()
  await productStore.initialize()

  const server = createServer({ productStore })
  server.listen(PORT, () => {
    console.log(`Inventory Manager is running on port ${PORT}.`)
  })

  const shutdown = () => {
    server.close(async () => {
      await productStore.close()
    })
  }
  process.once('SIGINT', shutdown)
  process.once('SIGTERM', shutdown)
}

if (require.main === module) {
  startServer().catch((error) => {
    console.error('Failed to start Inventory Manager:', error)
    process.exitCode = 1
  })
}

module.exports = { createServer, handleRequest }
