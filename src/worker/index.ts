import { Hono } from "hono";
const app = new Hono<{ Bindings: Env }>();

app.get("/api/", (c) => c.json({ name: "Cloudflare" }));
app.get("/api/health/db", async (c) => {
	const result = await c.env.DB.prepare("SELECT 1 AS ok").first<{ ok: number }>();

	return c.json({ database: result?.ok === 1 ? "ok" : "error" });
});

export default app;
