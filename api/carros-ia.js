// api/carros-ia.js
//
// Endpoint público, somente leitura, que lista os anúncios ativos do
// marketplace em TEXTO PURO (sem JavaScript, sem CSS, sem layout),
// incluindo titulo e descricao completos.
//
// Serve para ferramentas de IA/chatbot (ex.: Chatling) que só conseguem ler
// o HTML/texto bruto de uma URL, sem executar JavaScript — a página normal
// do marketplace carrega os carros via JS depois do load, então essas
// ferramentas veem só "Carregando...". Este endpoint resolve isso porque o
// servidor já monta o texto pronto antes de responder.
//
// URL depois de publicado: https://SEU-DOMINIO.vercel.app/api/carros-ia
// Essa é a URL que você cola no painel do Chatling como "fonte de dados".
//
// SEGURANCA / VISIBILIDADE — mesmas regras do marketplace publico:
//   - so inclui anuncios com status = 'ativo'  -> anuncio pendente de
//     aprovacao (recem-criado, ainda nao revisado pelo admin) NUNCA aparece
//     aqui, porque nasce com status = 'pendente' (trigger
//     trg_proteger_status_anuncios forca isso pra quem nao e admin).
//   - so inclui anuncios com pausado = false (ou nulo) -> quando um usuario
//     e banido, os anuncios dele sao marcados como pausado = true, entao
//     tambem somem daqui automaticamente, igual somem do marketplace.
// Ou seja: nao precisei mexer no banco pra isso, essas regras ja existiam
// (RLS + trigger), so estou reaproveitando os mesmos filtros na query.
//
// Usa a mesma chave publica (anon/publishable) que ja e usada no site
// inteiro. Nao expoe nada que a policy de RLS "Todos veem anuncios ativos"
// ja nao deixasse publico.

// Valores vêm das variáveis de ambiente da Vercel, não do código.
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;

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
      // pausado pode ser null (nunca pausado) ou false — cobre os dois casos
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
    // cache curto: os dados mudam com anuncios novos/pausados, mas nao
    // precisa ser 100% instantaneo para o treinamento do chatbot
    res.setHeader("Cache-Control", "public, max-age=300");
    res.status(200).send(texto);
  } catch (err) {
    res.status(500).send("Erro interno ao gerar lista de veiculos: " + err.message);
  }
}
