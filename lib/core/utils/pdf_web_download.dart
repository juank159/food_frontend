// lib/core/utils/pdf_web_download.dart
//
// Descarga forzada de un PDF en navegador, como último fallback cuando
// `share_plus` no puede abrir el picker real de compartir (navegador sin
// soporte de Web Share API para archivos, o activación del gesto vencida
// por el tiempo que tardó en generarse el PDF).
//
// Por qué no usar `Printing.sharePdf` acá: en web arma el Blob como
// `application/pdf`, y Chrome para Android (en especial dentro de una PWA
// instalada) por defecto ABRE su visor de PDF integrado en vez de
// descargar — y ese visor tiene su PROPIO botón "Compartir" que agrega el
// link `blob:` del propio visor junto al documento ("1 enlace y 1
// documento"), algo que no podemos controlar ni evitar una vez que Chrome
// decide mostrar su visor. Acá armamos el Blob como
// `application/octet-stream`: Chrome no lo reconoce como "PDF
// visualizable" y simplemente descarga el archivo crudo, sin abrir
// ningún visor ni ofrecer ningún botón de compartir — exactamente lo que
// querés como fallback silencioso (compartir de verdad vía share_plus es
// siempre el camino principal; esto solo entra cuando eso no es posible).
export 'pdf_web_download_stub.dart'
    if (dart.library.html) 'pdf_web_download_web.dart';
