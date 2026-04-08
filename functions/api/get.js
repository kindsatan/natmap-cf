export async function onRequestGet(context){
  try {
    const db = context.env.DB
    
    if (!db) {
      return new Response(JSON.stringify({error: "Database not configured"}), {
        status: 500,
        headers: {"Content-Type": "application/json"}
      })
    }
    
    const url = new URL(context.request.url)
    const tenant = url.searchParams.get("tenant")
    const app = url.searchParams.get("app")
    
    if (!tenant || !app) {
      return new Response(JSON.stringify({error: "Missing tenant or app parameter"}), {
        status: 400,
        headers: {"Content-Type": "application/json"}
      })
    }

    const result = await db.prepare(`
      SELECT public_ip,public_port,updated_at
      FROM mappings m
      JOIN tenants t ON m.tenant_id=t.id
      JOIN apps a ON m.app_id=a.id
      WHERE t.name=? AND a.app_name=?
      ORDER BY updated_at DESC
      LIMIT 1
    `)
    .bind(tenant,app)
    .first()

    if(!result){
      return new Response(JSON.stringify({error: "not found"}), {
        status: 404,
        headers: {"Content-Type": "application/json"}
      })
    }

    return Response.json(result)
  } catch (error) {
    return new Response(JSON.stringify({error: error.message}), {
      status: 500,
      headers: {"Content-Type": "application/json"}
    })
  }
}