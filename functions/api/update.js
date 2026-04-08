export async function onRequestPost(context){
  try {
    const db = context.env.DB
    
    if (!db) {
      return new Response(JSON.stringify({error: "Database not configured"}), {
        status: 500,
        headers: {"Content-Type": "application/json"}
      })
    }
    
    const tenant_id = context.data.tenant_id
    const body = await context.request.json()

    const app = body.app
    const ip = body.ip
    const port = body.port
    const proto = body.proto
    const local_ip = body.local_ip
    const local_port = body.local_port

    const appRow = await db.prepare(
      "SELECT id FROM apps WHERE tenant_id=? AND app_name=?"
    ).bind(tenant_id,app).first()

    if(!appRow){
      return new Response(JSON.stringify({error: "app not found"}), {
        status: 404,
        headers: {"Content-Type": "application/json"}
      })
    }

    await db.prepare(
      "DELETE FROM mappings WHERE tenant_id=? AND app_id=?"
    ).bind(tenant_id,appRow.id).run()

    await db.prepare(`
      INSERT INTO mappings
      (tenant_id,app_id,public_ip,public_port,local_ip,local_port,protocol,updated_at)
      VALUES (?,?,?,?,?,?,?,CURRENT_TIMESTAMP)
    `)
    .bind(
      tenant_id,
      appRow.id,
      ip,
      port,
      local_ip,
      local_port,
      proto
    )
    .run()

    return Response.json({status:"ok"})
  } catch (error) {
    return new Response(JSON.stringify({error: error.message}), {
      status: 500,
      headers: {"Content-Type": "application/json"}
    })
  }
}