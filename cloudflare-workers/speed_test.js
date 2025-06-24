/*
    测速地址格式：https://custom-domain/speedtest?bytes=10485760
*/
const createResponse = (data, status = 200, contentType = 'application/json') => {
    const body = contentType === 'application/json' ? JSON.stringify(data) : data;
    return new Response(body, {
        status,
        headers: {
            'Content-Type': `${contentType}; charset=utf-8`,
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type'
        }
    });
};

const handleError = (message, status = 500) => {
    return createResponse({ code: status, message }, status);
};

async function speedtest(request, url) {
    try {
        const bytes = url.searchParams.get('bytes');
        if (!bytes) {
            return handleError('请提供测试大小(bytes)', 400);
        }

        const speedTestUrl = `https://speed.cloudflare.com/__down?bytes=${bytes}`;
        const response = await fetch(speedTestUrl, {
            method: request.method,
            headers: request.headers
        });

        return new Response(response.body, {
            status: response.status,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Content-Type': 'application/octet-stream'
            }
        });
    } catch (error) {
        return handleError('测速失败: ' + error.message);
    }
}

export default {
    async fetch(request) {
        try {
            const url = new URL(request.url);
            if (url.pathname === '/speedtest') {
                return await speedtest(request, url);
            }
            return handleError('未找到测速路径', 404);
        } catch (error) {
            return handleError('服务器错误: ' + error.message);
        }
    }
};
