<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';

const props = defineProps({
  headerTitle: { type: String, default: '' },
  buttonLabel: { type: String, default: '' },
  searchQuery: { type: String, default: '' },
  statusFilter: { type: String, default: 'all' },
  statusFilterOptions: { type: Array, default: () => [] },
  statusFilterLabel: { type: String, default: '' },
  showStatusFilter: { type: Boolean, default: true },
  inboxFilter: { type: String, default: 'all' },
  inboxFilterOptions: { type: Array, default: () => [] },
  inboxFilterLabel: { type: String, default: '' },
  showInboxFilter: { type: Boolean, default: true },
  currentPage: { type: Number, default: 1 },
  totalItems: { type: Number, default: 0 },
});

const emit = defineEmits([
  'click',
  'close',
  'search',
  'update:statusFilter',
  'update:inboxFilter',
  'update:currentPage',
]);

const ITEMS_PER_PAGE = 15;

const { t } = useI18n();

const showPagination = computed(() => props.totalItems > ITEMS_PER_PAGE);

const handleButtonClick = () => emit('click');
const handleSearch = value => emit('search', value);
const handleStatusChange = value => emit('update:statusFilter', value);
const handleInboxChange = value => emit('update:inboxFilter', value);
const handlePageChange = page => emit('update:currentPage', page);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="sticky top-0 z-10 px-6">
      <div class="w-full max-w-5xl mx-auto">
        <div
          class="flex flex-col sm:flex-row items-start sm:items-center justify-between w-full py-6 gap-2"
        >
          <span class="text-heading-1 text-n-slate-12">
            {{ headerTitle }}
          </span>
          <div class="flex items-center gap-3">
            <Input
              :model-value="searchQuery"
              :placeholder="t('CAMPAIGN.CARD.SEARCH_PLACEHOLDER')"
              icon="i-lucide-search"
              size="sm"
              class="w-56"
              @update:model-value="handleSearch"
            />
            <SelectMenu
              v-if="showStatusFilter && statusFilterOptions.length"
              :model-value="statusFilter"
              :options="statusFilterOptions"
              :label="statusFilterLabel"
              @update:model-value="handleStatusChange"
            />
            <SelectMenu
              v-if="showInboxFilter && inboxFilterOptions.length > 1"
              :model-value="inboxFilter"
              :options="inboxFilterOptions"
              :label="inboxFilterLabel"
              @update:model-value="handleInboxChange"
            />
            <div
              v-on-click-outside="[
                () => emit('close'),
                { ignore: ['dialog.ProseMirror-prompt-backdrop'] },
              ]"
              class="relative group/campaign-button"
            >
              <Button
                :label="buttonLabel"
                icon="i-lucide-plus"
                size="sm"
                class="group-hover/campaign-button:brightness-110"
                @click="handleButtonClick"
              />
              <slot name="action" />
            </div>
          </div>
        </div>
      </div>
    </header>
    <main class="flex-1 px-6 overflow-y-auto">
      <div class="w-full max-w-5xl mx-auto py-4">
        <slot name="default" />
      </div>
    </main>
    <footer
      v-if="showPagination"
      class="sticky bottom-0 z-10 px-6 py-3 lg:px-0"
    >
      <PaginationFooter
        :current-page="currentPage"
        :total-items="totalItems"
        :items-per-page="ITEMS_PER_PAGE"
        @update:current-page="handlePageChange"
      />
    </footer>
  </section>
</template>
