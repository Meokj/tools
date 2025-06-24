export default {
  async fetch(request, env) {
    const PREFIX = env.PREFIX || ""; 

    const ua = request.headers.get("User-Agent") || "";

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

    const url = new URL(request.url);
    let path = url.pathname;

    if (PREFIX) {
      if (path.startsWith(PREFIX)) {
        path = path.slice(PREFIX.length);
      }
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

    return new Response("File not found", { status: 404 });
  }
}
