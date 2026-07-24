// arquivo: tema.js
//
// Aplica o tema salvo (claro/escuro) assim que a página carrega, antes da
// primeira pintura, para evitar o "flash" de tema errado. Antes esse mesmo
// trecho estava copiado inline em cada página do site.
(function () {
  const t = localStorage.getItem('mg_tema') || 'claro';
  document.documentElement.setAttribute('data-tema', t);
  document.addEventListener('DOMContentLoaded', () => {
    document.body.setAttribute('data-tema', t);
  });
})();
