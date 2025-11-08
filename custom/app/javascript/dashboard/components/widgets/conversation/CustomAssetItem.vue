<script setup>
const props = defineProps({
  asset: { type: Object, required: true },
  config: { type: Object, required: true },
});

const emit = defineEmits(['share']);

const formatValue = (value, field) => {
  if (!value) return '-';

  try {
    switch (field.type) {
      case 'currency':
        return new Intl.NumberFormat('en-US', {
          style: 'currency',
          currency: field.format || 'USD',
        }).format(value);
      case 'date':
        return new Date(value).toLocaleDateString();
      case 'number':
        return new Intl.NumberFormat('en-US').format(value);
      case 'link':
        return value;
      default:
        return value;
    }
  } catch (error) {
    return value;
  }
};

const isLink = (field) => field.type === 'link';
</script>

<template>
  <div class="px-4 py-3 hover:bg-n-slate-1 transition-colors">
    <div class="space-y-1.5">
      <div
        v-for="field in config.display_config.fields"
        :key="field.key"
        class="flex justify-between text-sm gap-2"
      >
        <span class="text-n-slate-11 font-medium flex-shrink-0">
          {{ field.label }}:
        </span>
        <span
          v-if="isLink(field)"
          class="text-n-slate-12 text-right truncate"
        >
          <a
            :href="asset[field.key]"
            target="_blank"
            class="text-blue-600 hover:text-blue-800 inline-flex items-center"
          >
            {{ asset[field.key] }}
            <fluent-icon icon="open" class="ml-1" size="12" />
          </a>
        </span>
        <span v-else class="text-n-slate-12 text-right truncate">
          {{ formatValue(asset[field.key], field) }}
        </span>
      </div>
    </div>

    <button
      class="mt-3 w-full px-3 py-1.5 text-sm bg-n-brand text-white rounded hover:bg-n-brand-hover transition-colors inline-flex items-center justify-center"
      @click="emit('share', asset, config)"
    >
      <fluent-icon icon="share" class="mr-1.5" size="14" />
      Share via WhatsApp
    </button>
  </div>
</template>


