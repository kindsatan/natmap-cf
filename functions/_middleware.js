export async function onRequest(context) {
  try {
    const { request, env, next } = context
    const url = new URL(request.url)

    if (!url.pathname.startsWith("/api/")) {
      return next()
    }

    if (url.pathname === "/api/update") {
      
      if (!env.DB) {
        return new Response(JSON.stringify({error: "Database not configured"}), {
          status: 500,
          headers: {"Content-Type": "application/json"}
        })
      }

      const api_key = request.headers.get("X-API-Key")

      if (!api_key) {
        return new Response(JSON.stringify({error: "missing api_key"}), {
          status: 401,
          headers: {"Content-Type": "application/json"}
        })
      }

      const tenant = await env.DB.prepare(
        "SELECT id FROM tenants WHERE api_key=?"
      ).bind(api_key).first()

      if (!tenant) {
        return new Response(JSON.stringify({error: "invalid api_key"}), {
          status: 403,
          headers: {"Content-Type": "application/json"}
        })
      }

      context.data.tenant_id = tenant.id
    }

    return next()
  } catch (error) {
    return new Response(JSON.stringify({error: error.message}), {
      status: 500,
      headers: {"Content-Type": "application/json"}
    })
  }
}