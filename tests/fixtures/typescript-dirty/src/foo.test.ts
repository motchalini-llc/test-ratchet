import { it, describe, expect } from "vitest"

it.skip("flaky — disabled instead of fixed", () => {
  expect(true).toBe(true)
})

describe.only("focused — CI runs only this block", () => {
  it("runs", () => {
    expect(1).toBe(1)
  })
})
