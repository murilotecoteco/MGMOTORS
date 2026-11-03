import { defineConfig, devices } from "@playwright/test";
import { existsSync } from "node:fs";

const systemChromium = process.env.CHROMIUM_BIN || "/usr/bin/chromium";

export default defineConfig({
  testDir: "./tests/e2e",
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: false,
  reporter: process.env.CI ? "dot" : "list",
  use: {
    baseURL: process.env.E2E_BASE_URL || "http://127.0.0.1:4173",
    browserName: "chromium",
    headless: true,
    launchOptions: existsSync(systemChromium) ? { executablePath: systemChromium } : undefined,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  webServer: process.env.E2E_BASE_URL ? undefined : {
    command: "node scripts/serve-static.mjs",
    url: "http://127.0.0.1:4173/MG-INICIO/inicio.html",
    reuseExistingServer: !process.env.CI,
    timeout: 15_000,
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});
