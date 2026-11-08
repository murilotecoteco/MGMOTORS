import { test, expect } from "@playwright/test";

const pages = [
  ["/MG-INICIO/inicio.html", /Encontre o carro dos seus/, /MG\s?Motors/i],
  ["/MG-MARKETPLACE/marketplace.html", /Encontre seu próximo veículo/, /Marketplace/],
  ["/MG-DICAS/dicas.html", /Dicas|segurança/, /Dicas/],
  ["/MG-CONTATO/contato.html", /excelência/, /Contato/],
  ["/MG-LOGIN/login.html", /Entrar|Acesse/, /Login|Entrar/],
];

for (const [path, heading, title] of pages) {
  test(`loads ${path}`, async ({ page }) => {
    const response = await page.goto(path);
    expect(response?.status()).toBe(200);
    await expect(page).toHaveTitle(title);
    await expect(page.locator("h1").first()).toContainText(heading);
  });
}

test("accepts visitor terms and enables the consent state", async ({ page }) => {
  await page.addInitScript(() => localStorage.clear());
  await page.goto("/MG-INICIO/inicio.html");
  const banner = page.locator("#mg-banner-termos");
  await expect(banner).toBeVisible();
  await banner.locator("#mg-banner-aceitar").click();
  await expect.poll(() => page.evaluate(() => localStorage.getItem("mg_termos_aceitos"))).toBe("1");
});

test("rejects a contact submission filled by a bot", async ({ page }) => {
  await page.goto("/MG-CONTATO/contato.html");
  await page.locator("#contato-nome").fill("Teste Bot");
  await page.locator("#contato-email").fill("bot@example.com");
  await page.locator("#contato-assunto").fill("Teste");
  await page.locator("#contato-mensagem").fill("Mensagem automatizada inválida.");
  await page.locator("#contato-website").fill("https://spam.invalid");
  await page.locator("#btn-enviar-contato").click();
  await expect(page.locator("#contato-status")).toContainText("Aguarde alguns segundos");
});

test("keeps marketplace modal closed until the user requests it", async ({ page }) => {
  await page.goto("/MG-MARKETPLACE/marketplace.html");
  const modal = page.locator("#modal-add-car");
  await expect(modal).toHaveAttribute("aria-hidden", "true");
  await expect(modal).toHaveAttribute("inert", "");
});
