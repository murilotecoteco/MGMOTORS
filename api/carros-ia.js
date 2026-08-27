const SUPABASE_URL = "https://ilswwmjojfuvcgyymymb.supabase.co";
const SUPABASE_KEY = "sb_publishable_0vy8zcMmKEd8oomSUQvJ4Q_SMpqFcxD";

function formatarPreco(preco) {
  const n = Number(preco) || 0;
  return n.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
}

export default async function handler(req, res) {
  try {
    const select = [
      "id",
      "titulo",
      "descricao",
      "preco",
      "ano_fabricacao",
      "ano_modelo",
      "quilometragem",
      "horas_motor",
      "cor",
      "cidade",
      "estado",
      "cidade_display",
      "marca_texto",
      "modelo_texto",
      "tipo_veiculo",
      "marcas(nome)",
      "modelos(nome)",
    ].join(",");

    const params = new URLSearchParams({
      select,
      status: "eq.ativo",

      or: "(pausado.eq.false,pausado.is.null)",
      order: "criado_em.desc",
      limit: "500",
    });

    const resp = await fetch(
      `${SUPABASE_URL}/rest/v1/anuncios?${params.toString()}`,
      {
        headers: {
          apikey: SUPABASE_KEY,
          Authorization: `Bearer ${SUPABASE_KEY}`,
        },
      }
    );

    if (!resp.ok) {
      const errBody = await resp.text();
      res.status(502).send("Erro ao consultar os anuncios: " + errBody);
      return;
    }

    const anuncios = await resp.json();

    let texto = `Lista de veiculos disponiveis no MG Motors (atualizado em ${new Date().toLocaleString(
      "pt-BR"
    )}).\n`;
    texto += `Para ver fotos e falar com o vendedor, acesse: https://mgmotors.vercel.app/MG-MARKETPLACE/marketplace.html\n`;
    texto += `Total de anuncios ativos: ${anuncios.length}\n\n`;

    if (anuncios.length === 0) {
      texto += "Nenhum veiculo ativo no momento.\n";
    }

    for (const a of anuncios) {
      const marca = a.marca_texto || a.marcas?.nome || "";
      const modelo = a.modelo_texto || a.modelos?.nome || "";
      const linhas = [
        `- ${a.titulo || `${marca} ${modelo}`.trim()}`,
        `  Marca/Modelo: ${marca} ${modelo}`.trim(),
        `  Ano: ${a.ano_fabricacao || "?"}/${a.ano_modelo || "?"}`,
        `  Km: ${a.quilometragem != null ? a.quilometragem.toLocaleString("pt-BR") : "?"}`,
        a.horas_motor ? `  Horas de motor: ${a.horas_motor}` : null,
        `  Cor: ${a.cor || "nao informado"}`,
        `  Preco: ${formatarPreco(a.preco)}`,
        `  Local: ${a.cidade_display || a.cidade || ""}${a.estado ? " - " + a.estado : ""}`,
        a.descricao ? `  Descricao: ${a.descricao}` : "  Descricao: (nao informada)",
        "",
      ].filter(Boolean);
      texto += linhas.join("\n") + "\n";
    }

    res.setHeader("Content-Type", "text/plain; charset=utf-8");
   
    res.setHeader("Cache-Control", "public, max-age=300");
    res.status(200).send(texto);
  } catch (err) {
    res.status(500).send("Erro interno ao gerar lista de veiculos: " + err.message);
  }
}
