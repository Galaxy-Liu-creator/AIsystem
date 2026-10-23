import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

describe('logo-character.svg asset', () => {
  it('uses a tight viewBox and the 智课引擎 wordmark', () => {
    const svg = readFileSync(resolve(import.meta.dirname, '../public/logo-character.svg'), 'utf8')

    expect(svg).toContain('viewBox="0 0 340 100"')
    expect(svg).toContain('智课引擎')
    expect(svg).not.toContain('viewBox="0 0 1440 809.999993"')
    expect(svg).not.toContain('智课坊')
  })
})
