# ⚽ Mini Football: Ultimate Draft

¡Bienvenido a **Mini Football**, una experiencia única que combina una interfaz de selección de equipo web premium con un dinámico motor de juego de fútbol 2D!

## 🔗 ¡Pruébalo ahora!
Puedes jugar la versión estable directamente en tu navegador aquí:
👉 **[mini-football-two.vercel.app](https://mini-football-two.vercel.app/)**

---

## 🚀 Características Principales

### 📋 Sistema de Draft Web
*   **Interfaz Premium**: Diseñada con una estética moderna, efectos de brillo y tarjetas de jugadores detalladas.
*   **Modos de Juego**: Soporta tanto el clásico **6 vs 6** como un modo rápido de **3 vs 3**.
*   **Selector de Formaciones**: Elige entre diferentes estrategias tácticas (2-1-2, 2-2-1, 1-2-2) que se reflejan visualmente en el campo antes de empezar.
*   **Fútbol de Fantasía**: Los jugadores que elijas en la web son los que aparecerán en el partido real.

### 🎮 Gameplay (Godot Engine)
*   **Físicas Estilo Haxball**: Un sistema de rebotes y fricción optimizado para que el juego sea fluido y competitivo.
*   **Control Dinámico**: Controlas al jugador marcado con una **aurora blanca**.
*   **Cambio de Jugador Inteligente**: Pulsa la tecla **R** para cambiar instantáneamente al jugador más cercano a la pelota.
*   **IA Competitiva**: Tus compañeros y rivales se mueven tácticamente según sus roles (POR, DEF, MED, DEL).

---

## 🛠️ Controles del Juego
*   **Flechas / WASD**: Mover al jugador.
*   **Barra Espaciadora / C**: Patear la pelota (con buffer de disparo).
*   **Tecla R**: Cambiar de jugador activo.

---

## 🏗️ Tecnología
*   **Frontend**: HTML5, CSS3 (Vanilla) y JavaScript para la lógica del draft y persistencia en `localStorage`.
*   **Game Engine**: Godot Engine 4.x para el motor de físicas, animaciones y lógica de IA, exportado a WebAssembly (WASM).
*   **Hosting**: Desplegado en Vercel.

---

## 📂 Estructura del Proyecto
*   `/Cartas`: Contiene la interfaz de selección, estilos e imágenes de los jugadores.
*   `/Mini-Football`: Proyecto completo de Godot, incluyendo scripts de IA, escenas y spritesheets.
*   `/Mini-Football/Exports/web`: Los archivos compilados necesarios para correr el juego en la web.

---

Desarrollado con ❤️ para los amantes del fútbol arcade.
