# Biblioteca de terceiros

`pdf.min.js` e `pdf.worker.min.js` são o [pdf.js](https://mozilla.github.io/pdf.js/)
**3.11.174**, da Mozilla, sob licença Apache 2.0. São cópias exatas do que o
cdnjs serve nessa versão.

Estão aqui, e não numa CDN, porque a leitura de PDF parava de funcionar quando
algo no caminho bloqueava o domínio de fora — bloqueador de anúncios, rede de
trabalho ou moldura de aplicativo. Servidos junto com o app, funcionam
inclusive sem internet.

Para atualizar a versão, baixe os dois arquivos da mesma versão e troque os
endereços em `index.html` (`PDFJS_LOCAL`, `PDFJS_CDN` e os dois do worker).
