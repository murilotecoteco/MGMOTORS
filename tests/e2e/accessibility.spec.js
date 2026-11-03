import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const pages = [
  "/MG-INICIO/inicio.html",
  "/MG-MARKETPLACE/marketplace.html",
  "/MG-CONTATO/contato.html",
  "/MG-LOGIN/login.html",
  "/MG-DICAS/dicas.html",
];

for (const path of pages) {
  test(`has no critical accessibility violations: ${path}`, async ({ page }) => {
    await page.goto(path);
    await page.waitForTimeout(500);
    const results = await new AxeBuilder({ page })
      .disableRules(["color-contrast"])
      .analyze();
    const critical = results.violations.filter(({ impact }) => impact === "critical");
    expect(critical, critical.map(({ id, help }) => `${id}: ${help}`).join("\n")).toEqual([]);
  });
}
