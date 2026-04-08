export async function onRequestGet(context){

  const db = context.env.DB
  const url = new URL(context.request.url)

  const tenant = url.searchParams.get("tenant")
  const app = url.searchParams.get("app")

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
    return new Response("not found",{status:404})
  }

  return Response.json(result)
}