<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useDebounceFn } from '@vueuse/core';
import Report from 'dashboard/api/reports';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  campaignId: { type: [Number, String], required: true },
  channelType: { type: String, default: '' },
});

const { t } = useI18n();
const route = useRoute();

const loading = ref(false);
const records = ref([]);
const meta = ref({
  total: 0,
  page: 1,
  per_page: 25,
  total_pages: 0,
  has_engagement: false,
});
const currentPage = ref(1);
const filterQuery = ref('');
const sortBy = ref('created_at');
const sortOrder = ref('desc');

const isWhatsApp = computed(() =>
  (props.channelType || '').toLowerCase().includes('whatsapp')
);

const showEngagement = computed(() => meta.value.has_engagement);
const showClicked = computed(() => showEngagement.value && !isWhatsApp.value);

const openedLabel = computed(() =>
  isWhatsApp.value
    ? t('CAMPAIGN_REPORTS.MESSAGES_TABLE.READ')
    : t('CAMPAIGN_REPORTS.MESSAGES_TABLE.OPENED')
);

const isSms = computed(() =>
  (props.channelType || '').toLowerCase().includes('sms')
);

const filterPlaceholder = computed(() => {
  if (isWhatsApp.value)
    return t('CAMPAIGN.DETAIL_PAGE.FILTER_PLACEHOLDER_WHATSAPP');
  if (isSms.value) return t('CAMPAIGN.DETAIL_PAGE.FILTER_PLACEHOLDER_SMS');
  return t('CAMPAIGN.DETAIL_PAGE.FILTER_PLACEHOLDER_EMAIL');
});

const paginationInfo = computed(() => {
  const total = meta.value.total;
  if (!total) return '';
  const from = (currentPage.value - 1) * meta.value.per_page + 1;
  const to = Math.min(currentPage.value * meta.value.per_page, total);
  return t('CAMPAIGN_REPORTS.MESSAGES_TABLE.PAGINATION_INFO', {
    from,
    to,
    total,
  });
});

const accountId = computed(() => route.params.accountId);

function contactRoute(contactId) {
  if (!contactId) return null;
  return `/app/accounts/${accountId.value}/contacts/${contactId}`;
}

async function fetchPage(page) {
  loading.value = true;
  try {
    const { data } = await Report.getCampaignMessages({
      campaignId: props.campaignId,
      page,
      sortBy: sortBy.value,
      sortOrder: sortOrder.value,
      filter: filterQuery.value || undefined,
    });
    records.value = data.data;
    meta.value = data.meta;
    currentPage.value = page;
  } catch {
    records.value = [];
  } finally {
    loading.value = false;
  }
}

function handleSort(column) {
  if (sortBy.value === column) {
    sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc';
  } else {
    sortBy.value = column;
    sortOrder.value = 'desc';
  }
  fetchPage(1);
}

function sortIcon(column) {
  if (sortBy.value !== column) return 'i-lucide-arrow-up-down';
  return sortOrder.value === 'asc'
    ? 'i-lucide-arrow-up'
    : 'i-lucide-arrow-down';
}

const debouncedFilter = useDebounceFn(() => fetchPage(1), 300);

function handleFilterInput(value) {
  filterQuery.value = value;
  debouncedFilter();
}

function statusClass(status) {
  const map = {
    sent: 'bg-n-amber-3 text-n-amber-11',
    delivered: 'bg-n-teal-3 text-n-teal-11',
    read: 'bg-n-blue-3 text-n-blue-11',
    failed: 'bg-n-ruby-3 text-n-ruby-11',
  };
  return map[status] || 'bg-n-alpha-2 text-n-slate-11';
}

function formatTime(iso) {
  if (!iso) return '\u2014';
  return new Date(iso).toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function engagementValue(row) {
  if (isWhatsApp.value) return row.status === 'read' ? '\u2713' : '\u2014';
  return row.opened_at ? formatTime(row.opened_at) : '\u2014';
}

function errorTooltip(row) {
  if (!row.error_message) return '';
  return row.error_code
    ? `[${row.error_code}] ${row.error_message}`
    : row.error_message;
}

watch(
  () => props.campaignId,
  () => fetchPage(1)
);
onMounted(() => fetchPage(1));
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-3">
      <h4 class="text-sm font-semibold text-n-slate-12">
        {{ t('CAMPAIGN_REPORTS.MESSAGES_TABLE.TITLE') }}
      </h4>
      <Input
        :model-value="filterQuery"
        :placeholder="filterPlaceholder"
        icon="i-lucide-search"
        size="sm"
        class="w-56"
        @update:model-value="handleFilterInput"
      />
    </div>

    <div v-if="loading" class="space-y-2">
      <div
        v-for="n in 5"
        :key="n"
        class="h-8 animate-pulse rounded bg-n-alpha-2"
      />
    </div>

    <div
      v-else-if="!records.length"
      class="py-8 text-center text-sm text-n-slate-10"
    >
      {{ t('CAMPAIGN_REPORTS.MESSAGES_TABLE.NO_DATA') }}
    </div>

    <template v-else>
      <div class="overflow-x-auto rounded-lg border border-n-weak">
        <table class="w-full text-left text-xs">
          <thead>
            <tr class="border-b border-n-weak bg-n-alpha-1">
              <th
                class="px-3 py-2 text-xs font-medium text-n-slate-11 uppercase tracking-wide cursor-pointer hover:text-n-slate-12 select-none"
                @click="handleSort('contact_name')"
              >
                <span class="inline-flex items-center gap-1">
                  {{ t('CAMPAIGN_REPORTS.MESSAGES_TABLE.CONTACT') }}
                  <Icon :icon="sortIcon('contact_name')" class="size-3" />
                </span>
              </th>
              <th
                class="px-3 py-2 text-xs font-medium text-n-slate-11 uppercase tracking-wide"
              >
                {{ t('CAMPAIGN_REPORTS.MESSAGES_TABLE.EMAIL_PHONE') }}
              </th>
              <th
                class="px-3 py-2 text-xs font-medium text-n-slate-11 uppercase tracking-wide cursor-pointer hover:text-n-slate-12 select-none"
                @click="handleSort('status')"
              >
                <span class="inline-flex items-center gap-1">
                  {{ t('CAMPAIGN_REPORTS.MESSAGES_TABLE.STATUS') }}
                  <Icon :icon="sortIcon('status')" class="size-3" />
                </span>
              </th>
              <th
                class="px-3 py-2 text-xs font-medium text-n-slate-11 uppercase tracking-wide cursor-pointer hover:text-n-slate-12 select-none"
                @click="handleSort('created_at')"
              >
                <span class="inline-flex items-center gap-1">
                  {{ t('CAMPAIGN_REPORTS.MESSAGES_TABLE.SENT_AT') }}
                  <Icon :icon="sortIcon('created_at')" class="size-3" />
                </span>
              </th>
              <th
                v-if="showEngagement"
                class="px-3 py-2 text-xs font-medium text-n-slate-11 uppercase tracking-wide cursor-pointer hover:text-n-slate-12 select-none"
                @click="handleSort('opened_at')"
              >
                <span class="inline-flex items-center gap-1">
                  {{ openedLabel }}
                  <Icon :icon="sortIcon('opened_at')" class="size-3" />
                </span>
              </th>
              <th
                v-if="showClicked"
                class="px-3 py-2 text-xs font-medium text-n-slate-11 uppercase tracking-wide cursor-pointer hover:text-n-slate-12 select-none"
                @click="handleSort('clicked_at')"
              >
                <span class="inline-flex items-center gap-1">
                  {{ t('CAMPAIGN_REPORTS.MESSAGES_TABLE.CLICKED') }}
                  <Icon :icon="sortIcon('clicked_at')" class="size-3" />
                </span>
              </th>
              <th
                class="px-3 py-2 text-xs font-medium text-n-slate-11 uppercase tracking-wide cursor-pointer hover:text-n-slate-12 select-none"
                @click="handleSort('replied_at')"
              >
                <span class="inline-flex items-center gap-1">
                  {{ t('CAMPAIGN_REPORTS.MESSAGES_TABLE.REPLIED') }}
                  <Icon :icon="sortIcon('replied_at')" class="size-3" />
                </span>
              </th>
              <th
                class="px-3 py-2 text-xs font-medium text-n-slate-11 uppercase tracking-wide"
              >
                {{ t('CAMPAIGN_REPORTS.MESSAGES_TABLE.ERROR') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in records"
              :key="row.id"
              class="border-b border-n-weak last:border-0 hover:bg-n-alpha-1"
            >
              <td class="px-3 py-2 text-n-slate-12">
                <router-link
                  v-if="row.contact_id"
                  :to="contactRoute(row.contact_id)"
                  class="text-n-blue-11 hover:underline font-medium"
                >
                  {{ row.contact_name || '\u2014' }}
                </router-link>
                <span v-else>{{ row.contact_name || '\u2014' }}</span>
              </td>
              <td class="px-3 py-2 text-n-slate-11">
                {{ row.contact_identifier || '\u2014' }}
              </td>
              <td class="px-3 py-2">
                <span
                  class="inline-block rounded-full px-2 py-0.5 text-xs font-medium"
                  :class="statusClass(row.status)"
                >
                  {{ row.status }}
                </span>
              </td>
              <td class="px-3 py-2 text-n-slate-11">
                {{ formatTime(row.created_at) }}
              </td>
              <td v-if="showEngagement" class="px-3 py-2 text-n-slate-11">
                {{ engagementValue(row) }}
              </td>
              <td v-if="showClicked" class="px-3 py-2 text-n-slate-11">
                {{ row.clicked_at ? formatTime(row.clicked_at) : '\u2014' }}
              </td>
              <td class="px-3 py-2 text-n-slate-11">
                {{ row.replied_at ? formatTime(row.replied_at) : '\u2014' }}
              </td>
              <td class="px-3 py-2 max-w-[200px]">
                <span
                  v-if="row.error_message"
                  v-tooltip.top="errorTooltip(row)"
                  class="inline-flex items-center gap-1 max-w-full cursor-default"
                >
                  <span
                    v-if="row.error_code"
                    class="shrink-0 text-[10px] font-mono px-1 py-0.5 rounded bg-n-ruby-3 text-n-ruby-11"
                  >
                    {{ row.error_code }}
                  </span>
                  <span class="text-xs text-n-ruby-11 truncate">
                    {{ row.error_message }}
                  </span>
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        v-if="meta.total_pages > 1"
        class="mt-3 flex items-center justify-between"
      >
        <span class="text-xs text-n-slate-10">
          {{ paginationInfo }}
        </span>
        <div class="flex gap-2">
          <Button
            :label="t('CAMPAIGN_REPORTS.MESSAGES_TABLE.PREV')"
            variant="faded"
            color="slate"
            size="xs"
            :disabled="currentPage <= 1"
            @click="fetchPage(currentPage - 1)"
          />
          <Button
            :label="t('CAMPAIGN_REPORTS.MESSAGES_TABLE.NEXT')"
            variant="faded"
            color="slate"
            size="xs"
            :disabled="currentPage >= meta.total_pages"
            @click="fetchPage(currentPage + 1)"
          />
        </div>
      </div>
    </template>
  </div>
</template>
