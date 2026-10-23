export async function loadDemoSnapshot(name) {
  try {
    const res = await fetch(`/media/demo/liuhan/${name}.json`, { cache: 'no-store' })
    if (!res.ok) return null
    return await res.json()
  } catch {
    return null
  }
}
