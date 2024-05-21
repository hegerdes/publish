const http = require('http');
const https = require('https');
const url = require('url');
const PORT = Number(process.env.PORT || 3000);

// AWS Lambda handler function
exports.handler = async (event, context) => {
    process.on('uncaughtException', function (err) {
        console.error('### uncaughtException (%s)', err);
        return {
            statusCode: 500,
            body: JSON.stringify(err),
            headers: { 'Content-Type': 'application/json' }
        }
    });

    console.log("Got lambda request")
    const out = await handleRequest(event.queryStringParameters || {}, event.headers)
    return {
        // Rewrite status because Hashicorp's stupids way of handling status codes
        statusCode: out.status,
        body: out.data,
        headers: { 'Content-Type': 'application/json' }
    };
}

// HTTP Server for local setup
const server = http.createServer(async (req, res) => {
    process.on('uncaughtException', function (err) {
        console.error('### uncaughtException (%s)', err);
        res.statusCode = 500;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ error: err.toString() }))
    });

    console.log('Incoming request from:', req.socket.remoteAddress);

    const out = await handleRequest(url.parse(req.url, true).query, req.headers);
    res.statusCode = out.status;
    res.setHeader('Content-Type', out.headers['content-type'] || 'application/json');
    res.end(out.data);

});

// Do the main work
const handleRequest = async (queryParams, headers) => {
    try {
        let payload = queryParams.payload
        const target = queryParams.target
        const method = (queryParams.method || "post").toUpperCase();
        const encoding = (queryParams.encoding || "none");

        if (!target) {
            console.error('Target url is required')
            return { status: 400, data: { error: 'Target url is required' } }
        }
        if (!payload) {
            console.error('Payload url is required')
            return { status: 400, data: { error: 'Payload url is required' } }
        }

        if (encoding.toLowerCase() === "urlencode") {
            payload = decodeURIComponent(payload)
        }
        if (encoding.toLowerCase() === "base64") {
            payload = Buffer.from(payload, 'base64').toString('utf-8')
        }

        delete headers['host']
        delete headers['Host']
        delete headers['X-Forwarded-Port']
        delete headers['X-Forwarded-Proto']
        const options = { method: method, headers: { ...headers, 'Content-Length': payload.length } }

        console.log('Making request to:', target)
        const upstream_res = await makeRequest(target, options, payload)

        // Rewrite status because Hashicorp's stupids way of handling status codes
        const status = target.includes('talos') && upstream_res.status >= 200 && upstream_res.status < 300 ? 200 : upstream_res.status
        return { status: status, data: upstream_res.data.toString(), headers: upstream_res.headers }
    }
    catch (error) {
        console.error('Error:', error)
        return { status: 500, data: { error: error.toString() } }
    }
}

// Helper request function
const makeRequest = (url, options = {}, data = null) => {
    return new Promise((resolve, reject) => {
        const req = https.request(url, options, (res) => {
            let chunks = [];
            res.on('data', (chunk) => {
                chunks.push(chunk);
            })
            req.on('error', (err) => {
                reject(err);
            });
            res.on("end", (_chunk) => {
                resolve({ status: res.statusCode, data: Buffer.concat(chunks), headers: res.headers });
            });
        })
        if (data) req.write(data)
        req.end()
    })
}

// Exit Signal
process.on('SIGTERM', () => {
    console.log('SIGTERM signal received...');
    shutdown();
});
// Exit Signal
process.on('SIGINT', () => {
    console.log('SIGINT received...');
    shutdown();
});
// Shutdown process
function shutdown () {
    server.close(() => {
        console.log('Server closed...');
    });
    process.exit(0);
}

// Start
if (require.main === module) {
    // this is the main module
    server.listen(PORT, () => {
        console.log(`Server running at http://[::]:${PORT}`);
    });
} else {
    // Stated as a included module
    console.log(`Code running as module...`);
}
