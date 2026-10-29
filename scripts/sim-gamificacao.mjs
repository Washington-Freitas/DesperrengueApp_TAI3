// Simulacao de unit economics e ranking da gamificacao.
// Premissas = docs/Fluxo de Caixa.md (ticket R$ 180, take-rate 12%, gateway 1,5% do GMV, impostos 6% da receita).
// Uso: node scripts/sim-gamificacao.mjs   (documentado em docs/GAMIFICACAO.md)
const P = { ticket: 180, take: 0.12, gateway: 0.015, tax: 0.06 };
const f2 = (x) => x.toFixed(2).replace('.', ',');
const pct = (x) => (x * 100).toFixed(1).replace('.', ',') + '%';

// contribuição por pedido dado o take-rate r
const contrib = (r, ticket = P.ticket) => ticket * r * (1 - P.tax) - ticket * P.gateway;
const c0 = contrib(P.take);
console.log('c0 (12%):', f2(c0), 'receita', f2(P.ticket * P.take), 'gateway', f2(P.ticket * P.gateway), 'imposto', f2(P.ticket * P.take * P.tax));

console.log('\n== Ligas (take-rate regressivo)');
const leagues = [['Oficial', 0.12], ['Especialista', 0.115], ['Mestre', 0.11], ['Lenda', 0.10]];
for (const [n, r] of leagues) {
  const c = contrib(r);
  const d = c0 - c;
  console.log(n.padEnd(13), pct(r).padStart(6), 'receita', f2(P.ticket * r).padStart(6), 'contrib', f2(c).padStart(6), 'custo do desconto', f2(d).padStart(5), 'queda', pct(d / c0).padStart(6));
}

console.log('\n== Bypass máximo tolerável (neutralidade) b <= 1 - (1-b0)*c0/c');
const b0s = [0.2, 0.3, 0.4, 0.5];
console.log('liga'.padEnd(13), b0s.map((b) => ('b0=' + pct(b)).padStart(11)).join(''));
for (const [n, r] of leagues.slice(1)) {
  const c = contrib(r);
  console.log(n.padEnd(13), b0s.map((b0) => { const bmax = 1 - (1 - b0) * c0 / c; return pct(bmax).padStart(11); }).join(''));
}
console.log('redução exigida (pp) para neutralidade:');
for (const [n, r] of leagues.slice(1)) {
  const c = contrib(r);
  console.log(n.padEnd(13), b0s.map((b0) => { const bmax = 1 - (1 - b0) * c0 / c; return ((b0 - bmax) * 100).toFixed(1).replace('.', ',').padStart(11); }).join(''));
}

console.log('\n== Cofre da Casa (cashback k% do GMV, resgate rho)');
for (const k of [0.01, 0.02, 0.03, 0.05]) {
  const row = [0.5, 0.65, 0.8, 1].map((rho) => { const cost = P.ticket * k * rho; return `rho=${rho * 100}%: custo ${f2(cost)} (${pct(cost / c0)} da contrib.)`; });
  console.log(`k=${pct(k)}`, row.join(' | '));
}

console.log('\n== Indicação "Salva-Vizinho": R$30 + R$30');
const ordersYear1 = 2.4; // pedidos/cliente/ano (premissa)
const ltv = ordersYear1 * c0;
console.log('LTV contrib. ano 1 (2,4 pedidos):', f2(ltv));
console.log('Custo do par R$30+R$30 =', f2(60), '-> LTV/CAC =', (ltv / 60).toFixed(2), '| pedidos p/ payback:', (60 / c0).toFixed(1));
for (const bonus of [10, 15, 20, 30]) console.log(`bônus total R$${bonus}`.padEnd(18), 'LTV/CAC', (ltv / bonus).toFixed(2), 'payback', (bonus / c0).toFixed(1), 'pedidos');
console.log('Bônus máximo p/ LTV/CAC=3:', f2(ltv / 3));

console.log('\n== Mix de ligas e impacto no Ano 1 (GMV 260.100)');
const mixes = { 'inicial 85/10/4/1': [0.85, 0.10, 0.04, 0.01], 'maduro 50/25/17/8': [0.5, 0.25, 0.17, 0.08] };
const GMV = 260100;
for (const [name, w] of Object.entries(mixes)) {
  const eff = leagues.reduce((s, [, r], i) => s + r * w[i], 0);
  const revLoss = GMV * (P.take - eff);
  const contribLoss = revLoss * (1 - P.tax);
  console.log(name.padEnd(20), 'take efetivo', pct(eff), 'receita perdida/ano R$', f2(revLoss), 'contrib. perdida R$', f2(contribLoss), '=', pct(contribLoss / 29295.54), 'da margem de contribuição do Ano 1 (R$ 29.295,54)');
}
// retenção necessária (GMV incremental) para compensar a perda a take-rate 12%
for (const [name, w] of Object.entries(mixes)) {
  const eff = leagues.reduce((s, [, r], i) => s + r * w[i], 0);
  const loss = GMV * (P.take - eff) * (1 - P.tax);
  const perExtraGmv = (eff * (1 - P.tax) - P.gateway); // contribuição por R$ de GMV incremental
  console.log(name.padEnd(20), 'GMV incremental p/ empatar R$', f2(loss / perExtraGmv), '=', pct(loss / perExtraGmv / GMV), 'do GMV do Ano 1');
}

console.log('\n== Escudo do Autônomo (seguro) — custo por profissional ativo');
for (const premium of [8, 12, 20]) {
  for (const orders of [4, 8, 12]) {
    const c = orders * c0;
    console.log(`prêmio R$${premium}/mês, ${orders} pedidos/mês: contrib. R$${f2(c)} -> prêmio = ${pct(premium / c)}`);
  }
}
console.log('Pedidos/mês p/ prêmio <= 15% da contribuição:', [8, 12, 20].map((p) => `R$${p}: ${(p / 0.15 / c0).toFixed(1)}`).join(' | '));

console.log('\n== Multiplicador de SLA/streak limitado e justiça do ranking');
const wr = (v, R, m, C) => v / (v + m) * R + m / (v + m) * C;
const q = (x) => (x - 1) / 4;
for (const beta of [0.08, 0.12, 0.20]) {
  const lo = 1 - beta / 2, hi = 1 + beta / 2;
  console.log(`beta=${beta}: alfa em [${lo.toFixed(2)}, ${hi.toFixed(2)}], razão máxima de vantagem ${(hi / lo).toFixed(3)}`);
}
// WR mínimo de B que ainda pode ultrapassar A (A com WR=4.80), com multiplicadores extremos
const WRa = 4.8;
for (const beta of [0.08, 0.12, 0.2]) {
  const lo = 1 - beta / 2, hi = 1 + beta / 2;
  // B com alfa=hi ultrapassa A com alfa=lo se q_B*hi > q_A*lo
  const qB = q(WRa) * lo / hi;
  console.log(`beta=${beta}: B ultrapassa A(WR=4,80) só se WR_B >= ${(qB * 4 + 1).toFixed(3)}`);
}
console.log('\nBayes (m=5, C=4,5): A=1 serviço 5,0 ->', wr(1, 5, 5, 4.5).toFixed(3), '| B=85 serviços 4,88 ->', wr(85, 4.88, 5, 4.5).toFixed(3), '| C=200 serviços 4,90 ->', wr(200, 4.9, 5, 4.5).toFixed(3));
console.log('Índice de confiança v/(v+m): v=1', pct(1 / 6), '| v=10', pct(10 / 15), '| v=50', pct(50 / 55), '| v=180', pct(180 / 185));
// m ótimo (Bayes empírico): m = sigma_w^2 / tau^2
for (const [sw2, t2] of [[0.6, 0.15], [0.8, 0.2], [0.5, 0.1]]) console.log(`sigma_w^2=${sw2}, tau^2=${t2} -> m = ${(sw2 / t2).toFixed(1)}`);
// quantas avaliações p/ chegar a 90% de confiança com m=5
console.log('v p/ 90% de confiança com m=5:', Math.ceil(0.9 * 5 / 0.1), '| 95%:', Math.ceil(0.95 * 5 / 0.05));
