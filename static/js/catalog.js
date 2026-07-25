// Каталог: дерево стилей, мульти-фильтры, слайдеры цены/ABV, пресеты, авто-сабмит.
(function () {
  const form = document.getElementById("catalogForm");
  if (!form) return;

  let submitTimer = null;
  function scheduleSubmit(delay) {
    clearTimeout(submitTimer);
    submitTimer = setTimeout(() => form.submit(), delay);
  }

  // ===================================================================
  // ДЕРЕВО СТИЛЕЙ (Семья → подстили, expand/collapse)
  // ===================================================================
  const styleInput = document.getElementById("styleInput");
  const familyInput = document.getElementById("familyInput");
  const styleTree = document.getElementById("styleTree");

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])
    );
  }

  if (styleTree) {
    // Раскрытие/закрытие семьи
    styleTree.querySelectorAll(".fst-family").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.preventDefault();
        btn.classList.toggle("open");
      });
    });

    // Чекбоксы стилей → обновляем hidden style и family
    const styleCbs = styleTree.querySelectorAll("input[data-style-cb]");
    function syncStyleInput() {
      const checked = Array.from(styleCbs)
        .filter((cb) => cb.checked)
        .map((cb) => cb.value);
      styleInput.value = checked.join(",");
      // Семья помечается выбранной, если выбран хотя бы один её стиль.
      // Также оставляем ручной выбор семьи через клик по заголовку семьи (ниже).
    }
    styleCbs.forEach((cb) => {
      cb.addEventListener("change", () => {
        syncStyleInput();
        // авто-раскрыть семью выбранного стиля
        const node = cb.closest(".fst-node");
        if (node) {
          const famBtn = node.querySelector(".fst-family");
          if (cb.checked && famBtn) famBtn.classList.add("open");
        }
        form.submit();
      });
    });

    // Клик по заголовку семьи (по иконке/имени, не по чекбоксу) — быстрый выбор всей семьи
    styleTree.querySelectorAll(".fst-family").forEach((btn) => {
      btn.addEventListener("dblclick", (e) => {
        e.preventDefault();
        const node = btn.closest(".fst-node");
        if (!node) return;
        const fid = node.dataset.family;
        // добавить/убрать семью в familyInput
        const cur = familyInput.value
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean);
        const idx = cur.indexOf(fid);
        if (idx >= 0) cur.splice(idx, 1);
        else cur.push(fid);
        familyInput.value = cur.join(",");
        form.submit();
      });
    });

    syncStyleInput();
  }

  // ===================================================================
  // МУЛЬТИ-СЕЛЕКТЫ (пивовар, страна)
  // ===================================================================
  function setupMultiSelect(displayId, optionsId, inputId, cbSelector, defaultText) {
    const display = document.getElementById(displayId);
    const options = document.getElementById(optionsId);
    const input = document.getElementById(inputId);
    if (!display || !options || !input) return;

    // Открытие/закрытие
    display.addEventListener("click", (e) => {
      e.preventDefault();
      document.querySelectorAll(".fs-ms-options.open").forEach((o) => {
        if (o !== options) o.classList.remove("open");
      });
      options.classList.toggle("open");
    });

    // Закрытие по клику вне
    document.addEventListener("click", (e) => {
      if (!display.contains(e.target) && !options.contains(e.target)) {
        options.classList.remove("open");
      }
    });

    // Поиск внутри длинного списка (для пивоварен)
    let searchBox = options.querySelector(".fs-ms-search");
    if (options.dataset.searchable === "1" && !searchBox) {
      searchBox = document.createElement("input");
      searchBox.type = "text";
      searchBox.className = "fs-ms-search";
      searchBox.placeholder = "поиск...";
      searchBox.addEventListener("input", () => {
        const q = searchBox.value.trim().toLowerCase();
        options.querySelectorAll(cbSelector).forEach((cb) => {
          const label = cb.closest(".fs-ms-option");
          if (!label) return;
          const match = cb.value.toLowerCase().includes(q);
          label.style.display = match ? "" : "none";
        });
      });
      options.insertBefore(searchBox, options.firstChild);
    }

    // Чекбоксы
    const checkboxes = options.querySelectorAll(cbSelector);
    function sync() {
      const checked = Array.from(checkboxes)
        .filter((cb) => cb.checked)
        .map((cb) => cb.value);
      input.value = checked.join(",");
      display.textContent = checked.length
        ? `Выбрано: ${checked.length}`
        : defaultText;
    }
    checkboxes.forEach((cb) => {
      cb.addEventListener("change", () => {
        sync();
        form.submit();
      });
    });
    sync();
  }

  setupMultiSelect(
    "producerMulti", "producerOptions", "producerInput",
    "input[data-producer-cb]", "Все пивовары"
  );
  const prodOpts = document.getElementById("producerOptions");
  if (prodOpts) prodOpts.dataset.searchable = "1";

  setupMultiSelect(
    "countryMulti", "countryOptions", "countryInput",
    "input[data-country-cb]", "Все страны"
  );

  // ===================================================================
  // УНИВЕРСАЛЬНЫЙ ДВОЙНОЙ СЛАЙДЕР (цена и ABV)
  // ===================================================================
  function setupDualSlider(cfg) {
    const minSlider = document.getElementById(cfg.minSlider);
    const maxSlider = document.getElementById(cfg.maxSlider);
    const minInput = document.getElementById(cfg.minInput);
    const maxInput = document.getElementById(cfg.maxInput);
    const rangeBar = document.getElementById(cfg.rangeBar);
    const valuesEl = document.getElementById(cfg.valuesEl);
    if (!minSlider || !maxSlider) return;
    const boundMin = parseFloat(minSlider.min);
    const boundMax = parseFloat(minSlider.max);
    let dragTimer = null;

    function update() {
      let lo = parseFloat(minSlider.value);
      let hi = parseFloat(maxSlider.value);
      if (lo > hi) {
        if (document.activeElement === minSlider) {
          maxSlider.value = lo;
          hi = lo;
        } else {
          minSlider.value = hi;
          lo = hi;
        }
      }
      const span = boundMax - boundMin;
      const leftPct = span > 0 ? ((lo - boundMin) / span) * 100 : 0;
      const rightPct = span > 0 ? ((hi - boundMin) / span) * 100 : 100;
      if (rangeBar) {
        rangeBar.style.left = leftPct + "%";
        rangeBar.style.right = 100 - rightPct + "%";
      }
      minInput.value = lo == boundMin ? "" : lo;
      maxInput.value = hi == boundMax ? "" : hi;
      if (valuesEl) {
        valuesEl.textContent = `${cfg.fmt ? cfg.fmt(lo) : lo}–${cfg.fmt ? cfg.fmt(hi) : hi}`;
      }
    }

    update();
    minSlider.addEventListener("input", () => {
      update();
      clearTimeout(dragTimer);
      dragTimer = setTimeout(() => scheduleSubmit(300), 200);
    });
    maxSlider.addEventListener("input", () => {
      update();
      clearTimeout(dragTimer);
      dragTimer = setTimeout(() => scheduleSubmit(300), 200);
    });
  }

  setupDualSlider({
    minSlider: "priceMinSlider", maxSlider: "priceMaxSlider",
    minInput: "priceMinInput", maxInput: "priceMaxInput",
    rangeBar: "priceRangeBar", valuesEl: "priceValues",
  });
  setupDualSlider({
    minSlider: "abvMinSlider", maxSlider: "abvMaxSlider",
    minInput: "abvMinInput", maxInput: "abvMaxInput",
    rangeBar: "abvRangeBar", valuesEl: "abvValues",
    fmt: (v) => Number(v).toFixed(1),
  });

  // ===================================================================
  // ПЕРЕКЛЮЧАТЕЛЬ ВИДА
  // ===================================================================
  document.querySelectorAll(".view-btn[data-view]").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      document.getElementById("viewInput").value = btn.dataset.view;
      try { localStorage.setItem("catalog_view", btn.dataset.view); } catch (err) {}
      form.submit();
    });
  });

  // ===================================================================
  // ЖИВЫЕ ПОДСКАЗКИ В ПОЛЕ «НАЗВАНИЕ» (как в шапке)
  // ===================================================================
  const nameInput = document.getElementById("nameInput");
  const nameBox = document.getElementById("nameSuggestBox");
  if (nameInput && nameBox) {
    let timer = null;
    let lastQuery = "";

    function render(items, correction) {
      if ((!items || items.length === 0) && !correction) {
        nameBox.hidden = true;
        nameBox.innerHTML = "";
        return;
      }
      let html = "";
      if (correction) {
        html +=
          `<a class="suggest-item suggest-correction" href="/search?q=${encodeURIComponent(correction)}">` +
          `<div class="si-main"><div class="si-name">💡 ${escapeHtml(correction)}</div>` +
          `<div class="si-meta">возможно, вы имели в виду</div></div></a>`;
      }
      if (items && items.length > 0) {
        html += items
          .map((it) => {
            const meta = [it.producer, it.style, it.abv ? it.abv + "% ABV" : ""]
              .filter(Boolean)
              .join(" · ");
            return `<a class="suggest-item" href="/beer/${it.id}">
              <div class="si-main">
                <div class="si-name">${escapeHtml(it.name)}</div>
                <div class="si-meta">${escapeHtml(meta)}</div>
              </div>
            </a>`;
          })
          .join("");
      }
      nameBox.innerHTML = html;
      nameBox.hidden = false;
    }

    nameInput.addEventListener("input", () => {
      const q = nameInput.value.trim();
      if (q === lastQuery) return;
      lastQuery = q;
      if (q.length < 2) {
        nameBox.hidden = true;
        return;
      }
      clearTimeout(timer);
      timer = setTimeout(() => {
        fetch("/api/suggest?q=" + encodeURIComponent(q))
          .then((r) => r.json())
          .then((data) => {
            if (Array.isArray(data)) {
              render(data, null);
            } else {
              render(data.suggestions || [], data.correction || null);
            }
          })
          .catch(() => { nameBox.hidden = true; });
      }, 200);
    });

    nameInput.addEventListener("focus", () => {
      if (nameBox.children.length > 0) nameBox.hidden = false;
    });

    document.addEventListener("click", (e) => {
      if (!nameInput.contains(e.target) && !nameBox.contains(e.target)) {
        nameBox.hidden = true;
      }
    });
  }

  // ===================================================================
  // ПРЕСЕТЫ ФИЛЬТРОВ (localStorage)
  // ===================================================================
  const PRESET_KEY = "catalog_presets";
  const saveBtn = document.getElementById("savePresetBtn");
  const presetList = document.getElementById("presetList");

  function getPresets() {
    try {
      return JSON.parse(localStorage.getItem(PRESET_KEY) || "{}");
    } catch (err) {
      return {};
    }
  }

  function savePresets(presets) {
    try {
      localStorage.setItem(PRESET_KEY, JSON.stringify(presets));
    } catch (err) {}
  }

  function renderPresets() {
    if (!presetList) return;
    const presets = getPresets();
    const names = Object.keys(presets);
    if (names.length === 0) {
      presetList.innerHTML = '<div class="fs-preset-empty">Нет сохранённых пресетов</div>';
      return;
    }
    presetList.innerHTML = names
      .map(
        (name) =>
          `<div class="fs-preset-item">
            <a href="/catalog?${presets[name]}" class="fs-preset-link">📌 ${escapeHtml(name)}</a>
            <button type="button" class="fs-preset-del" data-name="${escapeHtml(name)}" title="Удалить">✕</button>
          </div>`
      )
      .join("");
    presetList.querySelectorAll(".fs-preset-del").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.preventDefault();
        const name = btn.dataset.name;
        const presets = getPresets();
        delete presets[name];
        savePresets(presets);
        renderPresets();
      });
    });
  }

  if (saveBtn) {
    saveBtn.addEventListener("click", (e) => {
      e.preventDefault();
      const name = prompt("Название пресета:");
      if (!name) return;
      const params = new URLSearchParams(new FormData(form));
      params.delete("page");
      const qs = params.toString();
      const presets = getPresets();
      presets[name] = qs;
      savePresets(presets);
      renderPresets();
    });
  }

  renderPresets();

  // ===================================================================
  // МОБИЛЬНОЕ РАСКРЫТИЕ ФИЛЬТРОВ
  // ===================================================================
  const mobileToggle = document.getElementById("mobileFiltersToggle");
  const sidebar = document.getElementById("filtersSidebar");
  if (mobileToggle && sidebar) {
    mobileToggle.addEventListener("click", () => {
      sidebar.classList.toggle("mobile-open");
    });
  }

  // Авто-раскрытие семей, у которых выбраны стили (на старте)
  if (styleTree) {
    styleTree.querySelectorAll(".fst-node").forEach((node) => {
      const hasChecked = node.querySelector("input[data-style-cb]:checked");
      if (hasChecked) {
        node.querySelector(".fst-family")?.classList.add("open");
      }
    });
  }
})();
