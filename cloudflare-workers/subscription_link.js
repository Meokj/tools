export default {
	async fetch(request, env) {
		const PREFIX = env.PREFIX || "";
		const ua = request.headers.get("User-Agent") || "";
		const ip = request.headers.get("CF-Connecting-IP") || "unknown";
		const url = new URL(request.url);
		const blockList = [
			"Mozilla", "Chrome", "Safari", "Opera", "Edge", "MSIE", "Trident",
			"Baiduspider", "Yandex", "Sogou", "360SE", "Qihoo", "UCBrowser",
			"WebKit", "Bing", "Googlebot", "Yahoo", "Bot", "Crawler"
		];
		for (const keyword of blockList) {
			if (new RegExp(keyword, "i").test(ua)) {
				return new Response(null, {
					status: 404,
					headers: {
						"Content-Type": "text/plain",
						"Cache-Control": "no-store"
					}
				});
			}
		}
		let path = url.pathname;
		if (PREFIX && path.startsWith(PREFIX)) {
			path = path.slice(PREFIX.length);
		}
		path = path.replace(/^\/+/, "");
		const extensions = [".txt", ".yaml", ".json"];
		for (const ext of extensions) {
			const filePath = `${path}${ext}`;
			const apiUrl = `https://api.github.com/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/contents/${filePath}?ref=main`;
			const res = await fetch(apiUrl, {
				headers: {
					Authorization: `token ${env.GITHUB_TOKEN}`,
					Accept: "application/vnd.github.v3.raw",
					"User-Agent": "MyCloudflareWorker/1.0"
				}
			});
			if (res.status === 200) {
				function getShanghaiTime() {
					const date = new Date();
					return date.toLocaleString("zh-CN", {
						timeZone: "Asia/Shanghai",
						hour12: false
					}).replace(/\//g, "-");
				}
				const ts = getShanghaiTime();
				const logKey = `access_log:${ts}`;
				const logData = {
					ip,
					ua,
					file: filePath,
					ts
				};
				try {
					await env.ACCESS_LOG.put(logKey, JSON.stringify(logData));
					const list = await env.ACCESS_LOG.list({
						prefix: "access_log:"
					});
					const logs = list.keys.sort((a, b) => a.name.localeCompare(b.name));
					const extra = logs.length - 200;
					if (extra > 0) {
						const old = logs.slice(0, extra);
						for (const item of old) {
							await env.ACCESS_LOG.delete(item.name);
						}
					}
				} catch (err) {
					console.error("KV write failed", err);
				}
				let contentType = "text/plain";
				if (ext === ".json") contentType = "application/json";
				if (ext === ".yaml") contentType = "text/yaml";
				return new Response(await res.text(), {
					status: 200,
					headers: {
						"Content-Type": contentType,
						"Cache-Control": "no-store"
					}
				});
			}
		}
		return new Response("File not found", {
			status: 404
		});
	}
};
