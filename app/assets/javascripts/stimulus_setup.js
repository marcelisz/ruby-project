(function () {
  "use strict";

  if (!window.Stimulus) return;

  const application = Stimulus.Application.start();

  class FieldCardsController extends Stimulus.Controller {
    static targets = ["addForm", "template", "fieldList"];

    connect() {
      this.newFieldCount = 0;
      this.syncTuningForAll();

      if (window.Sortable) {
        new Sortable(this.fieldListTarget, {
          animation: 150,
          handle: "[data-drag-handle]",
          onEnd: () => this.syncPositions()
        });
      }
    }

    preventSubmit(event) {
      event.preventDefault();
    }

    add(event) {
      event.preventDefault();
      if (!this.addFormTarget.reportValidity()) return;

      const fragment = this.templateTarget.content.cloneNode(true);
      const card = fragment.querySelector("[data-field-card]");
      if (!card) return;

      const timestamp = Date.now();
      const suffix = `_new_${timestamp}_${++this.newFieldCount}`;
      const namespaceKey = `new_${timestamp}_${this.newFieldCount}`;
      card.querySelectorAll("[name]").forEach((element) => {
        element.name = element.name.replace(
          "inventory_fields[new_template]",
          `inventory_fields[${namespaceKey}]`
        );
      });
      card.querySelectorAll("[id]").forEach((element) => {
        element.id = `${element.id}${suffix}`;
      });
      card.querySelectorAll("label[for]").forEach((label) => {
        label.htmlFor = `${label.htmlFor}${suffix}`;
      });

      this.addFormTarget.querySelectorAll("input[name], select[name], textarea[name]").forEach((input) => {
        const keyMatch = input.name.match(/\[([^\]]+)\]$/);
        if (!keyMatch) return;
        const suffixMatch = `[${keyMatch[1]}]`;
        const candidates = Array.from(card.querySelectorAll("[name]"))
          .filter((candidate) => candidate.name.endsWith(suffixMatch));
        const target = candidates.find((candidate) => candidate.type === input.type) || candidates[0];
        if (!target) return;
        if (input.type === "checkbox") {
          target.checked = input.checked;
        } else {
          target.value = input.value;
        }
      });

      const title = this.addFormTarget.querySelector("[name='inventory_field[title]']")?.value.trim();
      const titleNode = card.querySelector("[data-field-title]");
      if (titleNode) titleNode.textContent = title || titleNode.textContent;

      const typeSelect = card.querySelector("[data-field-type-select]");
      const typeBadge = card.querySelector("[data-field-type-badge]");
      if (typeSelect && typeBadge) {
        typeBadge.textContent = typeSelect.selectedOptions[0]?.textContent.trim() || "";
      }

      this.fieldListTarget.appendChild(card);
      this.syncPositions();
      this.syncTuningFor(typeSelect);

      this.addFormTarget.reset();
      const addTypeSelect = this.addFormTarget.querySelector("[data-field-type-select]");
      addTypeSelect?.dispatchEvent(new Event("change", { bubbles: true }));
      card.querySelector("[data-field-title-input]")?.focus();
    }

    remove(event) {
      const card = event.target.closest("[data-field-card]");
      if (!card) return;

      const destroy = card.querySelector("[data-destroy-field]");
      if (destroy) destroy.value = "1";
      card.querySelectorAll("input, select, textarea, button").forEach((element) => {
        if (element.matches("[data-field-id-input], [data-destroy-field]")) return;
        element.disabled = true;
      });
      card.classList.add("d-none");
      this.syncPositions();
    }

    syncTuning(event) {
      this.syncTuningFor(event.currentTarget);
    }

    syncTuningForAll() {
      this.element.querySelectorAll("[data-field-type-select]").forEach((select) => {
        this.syncTuningFor(select);
      });
    }

    syncTuningFor(select) {
      if (!select) return;
      const scope = select.closest("[data-field-card], [data-add-field-form]");
      if (!scope) return;

      scope.querySelectorAll("[data-field-tuning-field]").forEach((field) => {
        const types = (field.dataset.fieldTypes || "").split(" ");
        field.classList.toggle("d-none", !types.includes(select.value));
      });
      scope.querySelectorAll("[data-field-tuning-label]").forEach((label) => {
        const types = (label.dataset.fieldTypes || "").split(" ");
        label.classList.toggle("d-none", !types.includes(select.value));
      });
    }

    syncPositions() {
      let position = 0;
      this.fieldListTarget.querySelectorAll("[data-field-card]:not(.d-none)").forEach((card) => {
        const input = card.querySelector("[data-field-position-input]");
        if (input) input.value = position++;
      });
    }
  }

  application.register("field-cards", FieldCardsController);
})();
