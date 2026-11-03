import { test, expect } from "@playwright/test";

const email = process.env.E2E_EMAIL;
const password = process.env.E2E_PASSWORD;

test.skip(!email || !password, "Defina E2E_EMAIL e E2E_PASSWORD para executar o fluxo autenticado.");

test("logs in and opens the account page", async ({ page }) => {
  await page.goto("/MG-LOGIN/login.html");
  await page.locator("#email").fill(email);
  await page.locator("#senha").fill(password);
  await page.locator("button[type=submit]").click();
  await expect(page).toHaveURL(/MG-(CONTA|INICIO)\//, { timeout: 15_000 });
  await page.goto("/MG-CONTA/conta.html");
  await expect(page.locator("h1").first()).toBeVisible();
});
