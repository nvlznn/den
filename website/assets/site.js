(() => {
  "use strict";

  const config = window.DEN_CONFIG || {};
  const sprites = window.DEN_SPRITES || {};
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ---------- App Store 按鈕與聯絡信箱 ----------

  document.querySelectorAll(".store-button").forEach((button) => {
    const label = button.querySelector("[data-label]");
    if (config.appStoreUrl) {
      button.href = config.appStoreUrl;
      button.removeAttribute("aria-disabled");
      if (label) label.textContent = "Download on the App Store";
    } else {
      button.removeAttribute("href");
      button.setAttribute("aria-disabled", "true");
      if (label) label.textContent = "Coming soon to the App Store";
    }
  });

  document.querySelectorAll("[data-support-email]").forEach((node) => {
    if (config.supportEmail) {
      const link = document.createElement("a");
      link.href = `mailto:${config.supportEmail}`;
      link.textContent = config.supportEmail;
      link.className = "text-link";
      node.replaceChildren(link);
    }
  });
  document.querySelectorAll("[data-support-block]").forEach((node) => {
    node.hidden = !config.supportEmail;
  });
  document.querySelectorAll("[data-support-fallback]").forEach((node) => {
    node.hidden = Boolean(config.supportEmail);
  });

  // ---------- LCD ----------

  const COLORS = { on: "#2a3225", off: "#94a47e" };

  // 和 app 一樣的 3×5 像素字，只收「Lv」和數字。
  const GLYPHS = {
    L: ["#..", "#..", "#..", "#..", "###"],
    v: ["...", "...", "#.#", "#.#", ".#."],
    " ": ["..", "..", "..", "..", ".."],
    0: ["###", "#.#", "#.#", "#.#", "###"],
    1: [".#.", "##.", ".#.", ".#.", "###"],
    2: ["###", "..#", "###", "#..", "###"],
    3: ["###", "..#", ".##", "..#", "###"],
    4: ["#.#", "#.#", "###", "..#", "..#"],
    5: ["###", "#..", "###", "..#", "###"],
    6: ["###", "#..", "###", "#.#", "###"],
    7: ["###", "..#", ".#.", ".#.", ".#."],
    8: ["###", "#.#", "###", "#.#", "###"],
    9: ["###", "#.#", "###", "..#", "###"],
  };

  function renderText(text) {
    const glyphs = [...text].map((c) => GLYPHS[c]).filter(Boolean);
    return [0, 1, 2, 3, 4].map((row) => glyphs.map((g) => g[row]).join("."));
  }

  /** 一塊點陣螢幕：固定格數，每一格是一個小方塊，沒亮的格子也畫出來。 */
  class LCD {
    constructor(canvas, columns, rows) {
      this.canvas = canvas;
      this.columns = columns;
      this.rows = rows;
      this.context = canvas.getContext("2d");
      this.resize();
      new ResizeObserver(() => this.resize()).observe(canvas);
    }

    resize() {
      const width = this.canvas.clientWidth || 200;
      const ratio = window.devicePixelRatio || 1;
      this.cell = Math.max(1, Math.floor((width * ratio) / this.columns));
      this.canvas.width = this.cell * this.columns;
      this.canvas.height = this.cell * this.rows;
      if (this.lastLayers) this.draw(this.lastLayers);
    }

    /** layers：[{ pixels: [String], x, y }]，`#` 是亮的像素。 */
    draw(layers) {
      this.lastLayers = layers;
      const lit = new Set();
      for (const { pixels, x, y } of layers) {
        pixels.forEach((line, dy) => {
          [...line].forEach((c, dx) => {
            const cx = x + dx;
            const cy = y + dy;
            if (c === "#" && cx >= 0 && cy >= 0 && cx < this.columns && cy < this.rows) {
              lit.add(cy * this.columns + cx);
            }
          });
        });
      }

      const { context: ctx, cell } = this;
      const gap = Math.max(1, Math.round(cell * 0.1));
      ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
      for (let row = 0; row < this.rows; row++) {
        for (let column = 0; column < this.columns; column++) {
          ctx.fillStyle = lit.has(row * this.columns + column) ? COLORS.on : COLORS.off;
          ctx.fillRect(column * cell, row * cell, cell - gap, cell - gap);
        }
      }
    }
  }

  // ---------- 寵物動畫（和 app 一樣：0.6 秒一格，開心時跳兩下） ----------

  const FRAME = 600;
  const HAPPY = 1500;

  function petFrame(character, now, happySince) {
    if (happySince && now - happySince < HAPPY) {
      const inAir = Math.floor((now - happySince) / (HAPPY / 4)) % 2 === 0;
      return { pixels: character.happy, dy: inAir ? -3 : 0 };
    }
    if (reduceMotion) return { pixels: character.idle, dy: 0 };
    const tick = Math.floor(now / FRAME);
    const blinks = tick % 9 === 4;
    return { pixels: blinks ? character.blink : character.idle, dy: tick % 2 ? 1 : 0 };
  }

  const loops = [];
  function everyFrame(callback) {
    loops.push(callback);
  }
  function run(now) {
    loops.forEach((callback) => callback(now));
    if (!reduceMotion) requestAnimationFrame(run);
  }

  // ---------- 首頁的大螢幕：輪流介紹每一隻 ----------

  const heroCanvas = document.querySelector("[data-hero-lcd]");
  const heroName = document.querySelector("[data-hero-name]");
  const order = ["fangfang", "doudou", "mochi", "drop", "cloud", "orb"].filter((id) => sprites[id]);
  // 示範用的等級，讓人看出每一隻各自成長。
  const demoLevels = { fangfang: 3, doudou: 1, mochi: 2, drop: 0, cloud: 5, orb: 4 };

  if (heroCanvas && order.length) {
    const lcd = new LCD(heroCanvas, 36, 30);
    let index = 0;
    let happySince = 0;
    let switchedAt = performance.now();

    const show = (i) => {
      index = (i + order.length) % order.length;
      switchedAt = performance.now();
      if (heroName) heroName.textContent = sprites[order[index]].name;
    };
    show(0);

    const heroScreen = heroCanvas.closest(".hero-lcd");
    const cheer = () => { happySince = performance.now(); };
    heroScreen.addEventListener("click", cheer);
    heroScreen.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        cheer();
      }
    });

    everyFrame((now) => {
      if (!reduceMotion && now - switchedAt > 6000) {
        show(index + 1);
      }
      const id = order[index];
      const frame = petFrame(sprites[id], now, happySince);
      lcd.draw([
        { pixels: renderText(`Lv ${demoLevels[id] ?? 0}`), x: 2, y: 2 },
        { pixels: frame.pixels, x: 10, y: 11 + frame.dy },
      ]);
    });
  }

  // ---------- 角色牆 ----------

  document.querySelectorAll("[data-character]").forEach((canvas) => {
    const character = sprites[canvas.dataset.character];
    if (!character) return;
    const lcd = new LCD(canvas, 20, 20);
    let happySince = 0;
    const cheer = () => { happySince = performance.now(); };
    const tile = canvas.closest(".lcd");
    tile.addEventListener("click", cheer);
    tile.addEventListener("mouseenter", cheer);
    tile.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        cheer();
      }
    });
    // 每一隻的眨眼錯開，不會一起眨。
    const offset = Math.random() * 5000;
    everyFrame((now) => {
      const frame = petFrame(character, now + offset, happySince ? happySince + offset : 0);
      lcd.draw([{ pixels: frame.pixels, x: 2, y: 3 + frame.dy }]);
    });
  });

  requestAnimationFrame(run);
})();
