describe('Smoke Test', () => {
  it('should pass basic math test', () => {
    expect(2 + 2).toBe(4)
  })

  it('should verify test environment is working', () => {
    expect(true).toBe(true)
  })

  it('should verify Jest matchers work', () => {
    const obj = { name: 'test', value: 123 }
    expect(obj).toEqual({ name: 'test', value: 123 })
    expect(obj).toHaveProperty('name')
    expect(obj.value).toBeGreaterThan(100)
  })
})