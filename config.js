// Endereço do banco. Sem isto preenchido o app funciona exatamente como
// antes: tudo guardado neste aparelho, sem servidor nenhum.
//
// Os dois valores saem do painel do Supabase, em Settings → API. A chave
// `anon` é pública de propósito — ela vai dentro da página, que qualquer
// pessoa consegue ler. Quem separa os dados de cada aluno são as políticas
// de acesso do banco (supabase/migrations/0003_politicas.sql), não esta
// chave. A chave `service_role` NUNCA entra aqui: ela ignora as políticas.
window.MSA_CONFIG = {
  supabaseUrl: '',
  supabaseAnonKey: '',
};
