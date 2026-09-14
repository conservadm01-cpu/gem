#!/bin/sh
# Junta as migrações num arquivo só, para instalar o banco de uma colada no
# Editor SQL do Supabase. As migrações continuam sendo a fonte da verdade:
# depois de mexer em qualquer uma delas, rode este script de novo.
#
#   sh supabase/gerar-setup.sh
set -e
cd "$(dirname "$0")"
{
  echo '-- ==================================================================='
  echo '-- Estudo Musical — MSA · instalação do banco numa colada só'
  echo '-- ==================================================================='
  echo '-- ARQUIVO GERADO por gerar-setup.sh — não edite aqui.'
  echo '-- É a junção de migrations/*.sql, na ordem. Mexer no banco se faz'
  echo '-- nas migrações; este arquivo é só a comodidade de instalar tudo de'
  echo '-- uma vez, colando no Editor SQL do Supabase.'
  echo '-- ==================================================================='
  echo
  for f in migrations/*.sql; do
    echo
    echo "-- >>>>>>>>>>>>>>>>>>>>>>>>>> $f"
    echo
    cat "$f"
  done
} > setup.sql
echo "setup.sql gerado com $(wc -l < setup.sql) linhas"
