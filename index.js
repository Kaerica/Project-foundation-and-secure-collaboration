const http = require('node:http')
const { products } = require('./products')

const PORT = Number(process.env.PORT) || 3000

function createServer () {
  return http.createServer((request, response) => {
    response.setHeader('Content-Type', 'application/json')

    if (request.method === 'GET' && request.url === '/health') {
      response.statusCode = 200
      response.end(JSON.stringify({ status: 'ok' }))
      return
    }

    if (request.method === 'GET' && request.url === '/') {
      response.statusCode = 200
      response.end(JSON.stringify({ products }))
      return
    }

    response.statusCode = 404
    response.end(JSON.stringify({ error: 'Not found.' }))
  })
}

if (require.main === module) {
  createServer().listen(PORT, () => {
    console.log(`Inventory Manager is running on port ${PORT}.`)
  })
}

module.exports = { createServer }
