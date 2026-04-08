export async function onRequest(context) {

  const { request, env, next } = context
  const url = new URL(request.url)

  if (!url.pathname.startsWith("/api/")) {
    return next()
  }

  if (url.pathname === "/api/update") {

    const api_key = request.headers.get("X-API-Key")

    if (!api_key) {
      return new Response("missing api_key",{status:401})
    }

    const tenant = await env.DB.prepare(
      "SELECT id FROM tenants WHERE api_key=?"
    ).bind(api_key).first()

    if (!tenant) {
      return new Response("invalid api_key",{status:403})
    }

    context.data.tenant_id = tenant.id
  }

  return next()
}