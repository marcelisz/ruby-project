(function () {
  "use strict";

  const csrfToken = () => document.querySelector('meta[name="csrf-token"]')?.content;

  function initPopovers(root = document) {
    if (!window.bootstrap) return;
    root.querySelectorAll('[data-bs-toggle="popover"]').forEach((element) => {
      if (bootstrap.Popover.getInstance(element)) return;
      new bootstrap.Popover(element, { trigger: "focus", container: "body" });
    });
  }

  function initRowLinks() {
    document.querySelectorAll("tr[data-href]").forEach((row) => {
      row.addEventListener("click", (event) => {
        if (event.target.closest("a, button, input, select, textarea, label, form")) return;
        if (window.getSelection()?.toString()) return;
        window.location.assign(row.dataset.href);
      });
    });
  }

  function initThemeSwitch() {
    document.querySelectorAll("[data-theme-form]").forEach((form) => {
      const toggle = form.querySelector("[data-theme-switch]");
      const input = form.querySelector('input[name="theme"]');
      if (!toggle || !input) return;
      toggle.addEventListener("change", () => {
        input.value = toggle.checked ? "dark" : "light";
        form.requestSubmit();
      });
    });
  }

  function initBulkSelection() {
    const selectAll = document.querySelector("#select-all-items");
    if (!selectAll) return;

    const checkboxes = Array.from(document.querySelectorAll(".js-item-checkbox"));
    const deleteButton = document.querySelector("[data-bulk-delete]");
    const refresh = () => {
      const checked = checkboxes.filter((checkbox) => checkbox.checked).length;
      selectAll.checked = checked === checkboxes.length && checkboxes.length > 0;
      selectAll.indeterminate = checked > 0 && checked < checkboxes.length;
      if (deleteButton) deleteButton.disabled = checked === 0;
    };

    selectAll.addEventListener("change", () => {
      checkboxes.forEach((checkbox) => { checkbox.checked = selectAll.checked; });
      refresh();
    });
    checkboxes.forEach((checkbox) => checkbox.addEventListener("change", refresh));
    refresh();
  }

  function initTagSelects() {
    if (!window.TomSelect) return;
    document.querySelectorAll("[data-tag-select]").forEach((select) => {
      new TomSelect(select, {
        plugins: ["remove_button"],
        create: true,
        persist: false,
        maxItems: null,
        placeholder: select.dataset.placeholder,
        load(query, callback) {
          if (!query.length) return callback();
          fetch(`${select.dataset.url}?q=${encodeURIComponent(query)}`, {
            headers: { Accept: "application/json" }
          })
            .then((response) => response.ok ? response.json() : [])
            .then(callback)
            .catch(() => callback());
        }
      });
    });
  }

  function initUserSelects() {
    if (!window.TomSelect) return;
    document.querySelectorAll("[data-user-select]").forEach((select) => {
      new TomSelect(select, {
        create: false,
        maxItems: 1,
        placeholder: select.dataset.placeholder,
        load(query, callback) {
          if (!query.length) return callback();
          fetch(`${select.dataset.url}?q=${encodeURIComponent(query)}`, {
            headers: { Accept: "application/json" }
          })
            .then((response) => response.ok ? response.json() : [])
            .then(callback)
            .catch(() => callback());
        }
      });
    });
  }

  function initCustomIdBuilder() {
    const form = document.querySelector("[data-custom-id-builder]");
    if (!form || !window.Sortable) return;

    let config;
    try {
      config = JSON.parse(form.dataset.builderConfig);
    } catch (_error) {
      return;
    }

    const hidden = form.querySelector("#custom-id-format");
    const list = form.querySelector("[data-custom-id-list]");
    const preview = document.querySelector("[data-custom-id-preview]");
    const count = form.querySelector("[data-custom-id-count]");
    const addButton = form.querySelector("[data-custom-id-add]");
    const typeSelect = form.querySelector("#custom-id-type");
    const max = Number(config.maxElements);
    const definitionFor = (type) => config.types[type] || {};
    const defaultsFor = (type) => {
      const definition = definitionFor(type);
      switch (definition.kind) {
        case "text": return { text: "" };
        case "random": return definition.padding ? { padding: definition.defaultPadding } : {};
        case "datetime": return { format: definition.defaultFormat };
        case "sequence": return { padding: definition.defaultPadding };
        default: return {};
      }
    };

    const gripIcon = '<svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><use href="#icon-grip"></use></svg>';
    const elements = () => Array.from(list.children).map((card) => {
      const element = { type: card.dataset.type };
      card.querySelectorAll("[data-config-key]").forEach((input) => {
        if (input.dataset.configKey === "padding") {
          const value = parseInt(input.value, 10);
          if (Number.isFinite(value)) element.padding = value;
        } else {
          element[input.dataset.configKey] = input.value;
        }
      });
      return element;
    });

    const randomDigits = (maxValue, width) =>
      String(Math.floor(Math.random() * maxValue)).padStart(width, "0");
    const guid = () => window.crypto?.randomUUID?.() || definitionFor("guid").sample || "";
    const dateSample = (format) =>
      format.replace(/%([YymdHMS%])/g, (_match, token) => token === "%" ? "%" : config.dateValues[token]);
    const example = (element) => {
      const definition = definitionFor(element.type);
      switch (definition.kind) {
        case "text": return element.text || "";
        case "random": {
          const width = definition.padding ?
            (Number(element.padding) || definition.defaultPadding) : definition.digits;
          return randomDigits(definition.max, width);
        }
        case "guid": return guid();
        case "datetime": return dateSample(element.format || definition.defaultFormat || "");
        case "sequence": return String(form.dataset.nextSequence || 1)
          .padStart(Number(element.padding) || definition.defaultPadding || 0, "0");
        default: return "";
      }
    };
    const refresh = () => {
      const current = elements();
      hidden.value = JSON.stringify(current);
      if (preview) preview.textContent = current.map(example).join("");
      if (count) count.textContent = `${current.length} / ${max}`;
      if (addButton) addButton.disabled = current.length >= max;
    };

    const configField = (parent, key, label, type, value, min, maxValue) => {
      const wrapper = document.createElement("div");
      wrapper.className = "mt-2";
      const id = `custom-id-${key}-${Math.random().toString(36).slice(2, 8)}`;
      const labelElement = document.createElement("label");
      labelElement.className = "form-label small mb-1";
      labelElement.htmlFor = id;
      labelElement.textContent = label;
      const input = document.createElement("input");
      input.className = "form-control form-control-sm";
      input.type = type;
      input.id = id;
      input.value = value;
      input.dataset.configKey = key;
      if (min !== undefined) input.min = min;
      if (maxValue !== undefined) input.max = maxValue;
      input.addEventListener("input", refresh);
      wrapper.append(labelElement, input);
      parent.appendChild(wrapper);
    };

    const addCard = (element) => {
      const card = document.createElement("div");
      card.className = "card";
      card.dataset.type = element.type;
      const body = document.createElement("div");
      body.className = "card-body py-2";

      const header = document.createElement("div");
      header.className = "d-flex flex-wrap align-items-center gap-2";
      const handle = document.createElement("button");
      handle.type = "button";
      handle.className = "btn btn-sm btn-outline-secondary";
      handle.dataset.dragHandle = "";
      handle.setAttribute("aria-label", config.labelsUi.drag);
      handle.title = config.labelsUi.drag;
      handle.innerHTML = gripIcon;
      const title = document.createElement("strong");
      title.className = "me-auto";
      title.textContent = config.labels[element.type] || element.type;
      const help = document.createElement("button");
      help.type = "button";
      help.className = "btn btn-sm btn-outline-secondary";
      help.textContent = config.labelsUi.help;
      help.dataset.bsToggle = "popover";
      help.dataset.bsTrigger = "focus";
      help.dataset.bsContent = config.helps[element.type] || "";
      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "btn-close";
      remove.setAttribute("aria-label", config.labelsUi.remove);
      remove.addEventListener("click", () => {
        bootstrap.Popover.getInstance(help)?.dispose();
        card.remove();
        refresh();
      });
      header.append(handle, title, help, remove);
      body.appendChild(header);

      if (element.type === "text") {
        configField(body, "text", config.labelsUi.text, "text", element.text || "");
      } else if (config.types[element.type]?.padding) {
        const range = config.types[element.type].padding;
        configField(body, "padding", config.labelsUi.padding, "number",
                    element.padding || config.types[element.type].defaultPadding || range[0],
                    range[0], range[1]);
      } else if (config.types[element.type]?.kind === "datetime") {
        configField(body, "format", config.labelsUi.format, "text",
                    element.format || config.types[element.type].defaultFormat);
      }

      card.appendChild(body);
      list.appendChild(card);
      initPopovers(card);
    };

    let initial;
    try {
      initial = JSON.parse(hidden.value || "[]");
    } catch (_error) {
      initial = [];
    }
    (Array.isArray(initial) ? initial : []).forEach((element) => addCard(element));

    new Sortable(list, {
      animation: 150,
      handle: "[data-drag-handle]",
      removeOnSpill: true,
      onEnd: refresh,
      onSpill: refresh
    });

    if (addButton) {
      addButton.addEventListener("click", () => {
        if (list.children.length >= max) return;
        const type = typeSelect.value;
        addCard({ type, ...defaultsFor(type) });
        refresh();
      });
    }
    refresh();
  }

  function initAutosave() {
    document.querySelectorAll("[data-autosave]").forEach((form) => {
      const url = form.dataset.autosaveUrl;
      const status = form.querySelector("[data-autosave-status]");
      const interval = Number(form.dataset.autosaveInterval) || 8000;
      if (!url) return;

      const serialized = () => new URLSearchParams(new FormData(form)).toString();
      let saved = serialized();
      let saving = false;

      setInterval(async () => {
        if (saving || !form.isConnected) return;
        const current = serialized();
        if (current === saved) return;

        saving = true;
        if (status) status.textContent = form.dataset.autosaveSaving;
        try {
          const response = await fetch(url, {
            method: "PATCH",
            headers: { Accept: "application/json", "X-CSRF-Token": csrfToken() },
            body: new FormData(form)
          });
          if (response.status === 409) {
            if (status) status.textContent = form.dataset.autosaveConflict;
            saved = current;
            return;
          }
          if (!response.ok) {
            if (status) status.textContent = form.dataset.autosaveError;
            saved = current;
            return;
          }
          const data = await response.json();
          const lock = form.querySelector('[name="inventory[lock_version]"]');
          if (lock && data.lock_version !== undefined) lock.value = data.lock_version;
          saved = serialized();
          if (status) status.textContent = form.dataset.autosaveSaved;
        } catch (_error) {
          if (status) status.textContent = form.dataset.autosaveError;
        } finally {
          saving = false;
        }
      }, interval);
    });
  }

  function initChat() {
    document.querySelectorAll("[data-chat]").forEach((chat) => {
      const container = chat.querySelector("[data-chat-messages]");
      const feedUrl = chat.dataset.feedUrl;
      if (!container || !feedUrl) return;

      let lastId = Number(chat.dataset.lastId) || 0;
      let polling = false;

      const poll = async () => {
        if (polling || document.hidden) return;
        polling = true;
        try {
          const response = await fetch(`${feedUrl}?after=${lastId}`, {
            headers: { Accept: "application/json" }
          });
          if (!response.ok) return;
          const data = await response.json();
          if (Number(data.last_id) <= lastId || !data.html) return;

          const nearBottom = window.innerHeight + window.scrollY >= document.body.offsetHeight - 180;
          container.querySelector("[data-chat-empty]")?.remove();
          container.insertAdjacentHTML("beforeend", data.html);
          lastId = Number(data.last_id);
          chat.dataset.lastId = String(lastId);
          if (nearBottom) window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" });
        } catch (_error) {
        } finally {
          polling = false;
        }
      };

      setInterval(poll, 3000);
    });
  }

  function initCloudinary() {
    document.querySelectorAll("[data-cloudinary-upload]").forEach((button) => {
      button.addEventListener("click", () => {
        if (!window.cloudinary) {
          window.alert(button.dataset.widgetError);
          return;
        }
        const input = document.getElementById(button.dataset.inputId);
        const preview = document.getElementById(button.dataset.previewId);
        const widget = window.cloudinary.createUploadWidget({
          cloudName: button.dataset.cloudName,
          uploadPreset: button.dataset.uploadPreset,
          multiple: false,
          maxFiles: 1,
          sources: ["local", "url"]
        }, (error, result) => {
          if (error || !result || result.event !== "success") return;
          if (input) {
            input.value = result.info.secure_url;
            input.dispatchEvent(new Event("change", { bubbles: true }));
          }
          if (preview) {
            preview.src = result.info.secure_url;
            preview.classList.remove("d-none");
          }
        });
        widget.open();
      });
    });
  }

  function initImageLightbox() {
    if (!window.GLightbox) return;

    window.GLightbox({
      selector: ".glightbox",
      touchNavigation: true,
      loop: false,
      openEffect: "fade",
      closeEffect: "fade"
    });
  }

  document.addEventListener("DOMContentLoaded", () => {
    initPopovers();
    initRowLinks();
    initThemeSwitch();
    initBulkSelection();
    initTagSelects();
    initUserSelects();
    initCustomIdBuilder();
    initAutosave();
    initChat();
    initCloudinary();
    initImageLightbox();
  });
})();
