(function () {
  "use strict";
  window.__BRAND__ = {
    name: "QR Listo",
    tagline: "Generador de códigos QR gratis",
    // Ejemplo que se muestra (en gris) mientras el visitante no ha escrito nada
    sampleData: "https://ejemplo.com",
    // Presets de estilo: cada uno fija puntos + esquinas + centro de esquinas a la vez
    styles: {
      clasico:    { dots: "square",         corners: "square",        cornerDot: "square" },
      redondeado: { dots: "rounded",        corners: "extra-rounded", cornerDot: "dot" },
      puntos:     { dots: "dots",           corners: "dot",           cornerDot: "dot" },
      elegante:   { dots: "classy-rounded", corners: "extra-rounded", cornerDot: "square" }
    },
    maxLogoBytes: 5 * 1024 * 1024
  };
})();
