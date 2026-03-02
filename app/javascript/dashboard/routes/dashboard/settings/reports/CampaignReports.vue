<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { generateFileName } from 'dashboard/helper/downloadHelper';
import ReportHeader from './components/ReportHeader.vue';
import ReportFilters from './components/ReportFilters.vue';
import BarChart from 'shared/components/charts/BarChart.vue';
import DoughnutChart from 'shared/components/charts/DoughnutChart.vue';
import { GROUP_BY_FILTER } from './constants';

const { t } = useI18n();
const store = useStore();

const from = ref(0);
const to = ref(0);
const groupBy = ref(GROUP_BY_FILTER[1]);

const summary = computed(() => store.getters.getCampaignReportSummary);
const campaignList = computed(() => store.getters.getCampaignReportList);
const timeseries = computed(() => store.getters.getCampaignReportTimeseries);
const channelBreakdownData = ref({});

const sortColumn = ref('reply_rate');
const sortDirection = ref('desc');
const currentPage = ref(1);
const pageSize = 10;

const sortedCampaignList = computed(() => {
  const list = [...campaignList.value];
  return list.sort((a, b) => {
    const aVal = a[sortColumn.value] ?? 0;
    const bVal = b[sortColumn.value] ?? 0;
    if (sortDirection.value === 'asc') return aVal > bVal ? 1 : -1;
    return aVal < bVal ? 1 : -1;
  });
});

const totalPages = computed(() =>
  Math.max(1, Math.ceil(sortedCampaignList.value.length / pageSize))
);

const paginatedCampaignList = computed(() => {
  const start = (currentPage.value - 1) * pageSize;
  return sortedCampaignList.value.slice(start, start + pageSize);
});

function toggleSort(col) {
  if (sortColumn.value === col) {
    sortDirection.value = sortDirection.value === 'asc' ? 'desc' : 'asc';
  } else {
    sortColumn.value = col;
    sortDirection.value = 'desc';
  }
  currentPage.value = 1;
}

function sortIndicator(col) {
  if (sortColumn.value !== col) return '';
  return sortDirection.value === 'asc' ? ' \u2191' : ' \u2193';
}

const summaryCards = computed(() => [
  {
    label: t('CAMPAIGN_REPORTS.CAMPAIGNS_CREATED'),
    value: summary.value.campaigns_created ?? 0,
  },
  {
    label: t('CAMPAIGN_REPORTS.TOTAL_SENT'),
    value: summary.value.total_sent ?? 0,
  },
  {
    label: t('CAMPAIGN_REPORTS.TOTAL_FAILED'),
    value: summary.value.total_failed ?? 0,
  },
  {
    label: t('CAMPAIGN_REPORTS.TOTAL_REPLIES'),
    value: summary.value.total_replies ?? 0,
  },
  {
    label: t('CAMPAIGN_REPORTS.REPLY_RATE'),
    value: `${summary.value.reply_rate ?? 0}%`,
  },
]);

const timeseriesChartData = computed(() => {
  const ts = timeseries.value;
  if (!ts.campaigns_created) return { labels: [], datasets: [] };
  const labels = Object.keys(ts.campaigns_created);
  return {
    labels,
    datasets: [
      {
        label: t('CAMPAIGN_REPORTS.CAMPAIGNS_CREATED'),
        data: labels.map(l => ts.campaigns_created[l] || 0),
        backgroundColor: 'rgb(31, 147, 255)',
      },
    ],
  };
});

const sentFailedChartData = computed(() => {
  const ts = timeseries.value;
  if (!ts.messages_sent) return { labels: [], datasets: [] };
  const labels = Object.keys(ts.messages_sent);
  return {
    labels,
    datasets: [
      {
        label: t('CAMPAIGN_REPORTS.TOTAL_SENT'),
        data: labels.map(l => ts.messages_sent[l] || 0),
        backgroundColor: 'rgb(46, 204, 113)',
      },
      {
        label: t('CAMPAIGN_REPORTS.TOTAL_FAILED'),
        data: labels.map(l => ts.messages_failed?.[l] || 0),
        backgroundColor: 'rgb(231, 76, 60)',
      },
    ],
  };
});

const channelChartData = computed(() => {
  const data = channelBreakdownData.value;
  if (!data || typeof data !== 'object' || Array.isArray(data))
    return { labels: [], datasets: [] };
  const labels = Object.keys(data);
  return {
    labels,
    datasets: [
      {
        data: Object.values(data),
        backgroundColor: [
          '#1f93ff',
          '#2ecc71',
          '#e74c3c',
          '#f39c12',
          '#9b59b6',
          '#1abc9c',
        ],
      },
    ],
  };
});

const deliveryBreakdown = ref({});

const deliveryChartData = computed(() => {
  const data = deliveryBreakdown.value;
  if (!data.succeeded && !data.failed && !data.pending)
    return { labels: [], datasets: [] };
  return {
    labels: [
      t('CAMPAIGN_REPORTS.SUCCEEDED'),
      t('CAMPAIGN_REPORTS.FAILED'),
      t('CAMPAIGN_REPORTS.PENDING'),
    ],
    datasets: [
      {
        data: [data.succeeded || 0, data.failed || 0, data.pending || 0],
        backgroundColor: ['#2ecc71', '#e74c3c', '#f39c12'],
      },
    ],
  };
});

const inboxBreakdown = ref({});

const inboxChartData = computed(() => {
  const data = inboxBreakdown.value;
  if (!data || typeof data !== 'object' || Array.isArray(data))
    return { labels: [], datasets: [] };
  const labels = Object.keys(data);
  return {
    labels,
    datasets: [
      {
        label: t('CAMPAIGN_REPORTS.CAMPAIGNS'),
        data: Object.values(data),
        backgroundColor: 'rgb(31, 147, 255)',
      },
    ],
  };
});

const heatmapData = ref([]);

const heatmapChartData = computed(() => {
  const matrix = heatmapData.value;
  if (!matrix || !matrix.length) return { labels: [], datasets: [] };
  const days = [
    t('CAMPAIGN_REPORTS.DAYS.SUN'),
    t('CAMPAIGN_REPORTS.DAYS.MON'),
    t('CAMPAIGN_REPORTS.DAYS.TUE'),
    t('CAMPAIGN_REPORTS.DAYS.WED'),
    t('CAMPAIGN_REPORTS.DAYS.THU'),
    t('CAMPAIGN_REPORTS.DAYS.FRI'),
    t('CAMPAIGN_REPORTS.DAYS.SAT'),
  ];
  const hours = Array.from({ length: 24 }, (_, i) => `${i}:00`);
  const datasets = matrix.map((dayData, idx) => ({
    label: days[idx],
    data: dayData,
    backgroundColor: `hsla(${(idx * 50) % 360}, 60%, 50%, 0.7)`,
  }));
  return { labels: hours, datasets };
});

async function fetchBreakdowns(payload) {
  try {
    const [channelRes, deliveryRes, inboxRes, heatmapRes] = await Promise.all([
      store.dispatch('fetchCampaignReportBreakdown', {
        ...payload,
        breakdownType: 'by_channel_type',
      }),
      store.dispatch('fetchCampaignReportBreakdown', {
        ...payload,
        breakdownType: 'delivery_status',
      }),
      store.dispatch('fetchCampaignReportBreakdown', {
        ...payload,
        breakdownType: 'by_inbox',
      }),
      store.dispatch('fetchCampaignReportBreakdown', {
        ...payload,
        breakdownType: 'by_hour_and_day',
      }),
    ]);
    channelBreakdownData.value = channelRes?.data || {};
    deliveryBreakdown.value = deliveryRes?.data || {};
    inboxBreakdown.value = inboxRes?.data || {};
    heatmapData.value = heatmapRes?.data || [];
  } catch {
    useAlert(t('REPORT.DATA_FETCHING_FAILED'));
  }
}

function fetchAllData() {
  const payload = { from: from.value, to: to.value };

  store.dispatch('fetchCampaignReportSummary', payload).catch(() => {
    useAlert(t('REPORT.SUMMARY_FETCHING_FAILED'));
  });

  store.dispatch('fetchCampaignReportList', payload);

  store.dispatch('fetchCampaignReportTimeseries', {
    ...payload,
    groupBy: groupBy.value?.period,
  });

  fetchBreakdowns(payload);
}

function onFilterChange({ from: f, to: t2, groupBy: g }) {
  from.value = f;
  to.value = t2;
  groupBy.value = g;
  currentPage.value = 1;
  fetchAllData();
}

function downloadCampaignList() {
  store.dispatch('downloadCampaignsCSV', {
    from: from.value,
    to: to.value,
    fileName: generateFileName({ type: 'campaigns', to: to.value }),
  });
}

function downloadDeliveryDetail() {
  store.dispatch('downloadCampaignDeliveryCSV', {
    from: from.value,
    to: to.value,
    fileName: generateFileName({
      type: 'campaign_delivery',
      to: to.value,
    }),
  });
}

const tableColumns = [
  { key: 'title', label: t('CAMPAIGN_REPORTS.TABLE.TITLE') },
  { key: 'channel_type', label: t('CAMPAIGN_REPORTS.TABLE.CHANNEL') },
  { key: 'succeeded', label: t('CAMPAIGN_REPORTS.TABLE.SENT') },
  { key: 'replies', label: t('CAMPAIGN_REPORTS.TABLE.REPLIES') },
  { key: 'reply_rate', label: t('CAMPAIGN_REPORTS.TABLE.REPLY_RATE') },
];
</script>

<template>
  <ReportHeader :header-title="$t('CAMPAIGN_REPORTS.HEADER')" />
  <div class="flex flex-col gap-4">
    <ReportFilters
      :show-entity-filter="false"
      show-group-by
      :show-business-hours="false"
      @filter-change="onFilterChange"
    />

    <!-- Summary metric cards -->
    <div class="grid grid-cols-5 gap-3">
      <div
        v-for="card in summaryCards"
        :key="card.label"
        class="rounded-lg border border-slate-100 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
      >
        <p
          class="mb-1 text-xs font-medium uppercase tracking-wide text-slate-600 dark:text-slate-300"
        >
          {{ card.label }}
        </p>
        <p class="text-2xl font-semibold text-slate-800 dark:text-slate-100">
          {{ card.value }}
        </p>
      </div>
    </div>

    <!-- Timeseries charts -->
    <div class="grid grid-cols-2 gap-4">
      <div
        class="rounded-lg border border-slate-100 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
      >
        <h3
          class="mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ $t('CAMPAIGN_REPORTS.CHARTS.CAMPAIGNS_OVER_TIME') }}
        </h3>
        <div class="h-64">
          <BarChart :collection="timeseriesChartData" />
        </div>
      </div>
      <div
        class="rounded-lg border border-slate-100 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
      >
        <h3
          class="mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ $t('CAMPAIGN_REPORTS.CHARTS.SENT_VS_FAILED') }}
        </h3>
        <div class="h-64">
          <BarChart
            :collection="sentFailedChartData"
            :chart-options="{
              scales: { x: { stacked: true }, y: { stacked: true } },
            }"
          />
        </div>
      </div>
    </div>

    <!-- Breakdown charts -->
    <div class="grid grid-cols-3 gap-4">
      <div
        class="rounded-lg border border-slate-100 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
      >
        <h3
          class="mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ $t('CAMPAIGN_REPORTS.CHARTS.BY_INBOX') }}
        </h3>
        <div class="h-64">
          <BarChart
            :collection="inboxChartData"
            :chart-options="{ indexAxis: 'y' }"
          />
        </div>
      </div>
      <div
        class="rounded-lg border border-slate-100 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
      >
        <h3
          class="mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ $t('CAMPAIGN_REPORTS.CHARTS.BY_CHANNEL') }}
        </h3>
        <div class="h-64">
          <DoughnutChart :collection="channelChartData" />
        </div>
      </div>
      <div
        class="rounded-lg border border-slate-100 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
      >
        <h3
          class="mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ $t('CAMPAIGN_REPORTS.CHARTS.DELIVERY_STATUS') }}
        </h3>
        <div class="h-64">
          <DoughnutChart :collection="deliveryChartData" />
        </div>
      </div>
    </div>

    <!-- Per-campaign reply rate table -->
    <div
      class="rounded-lg border border-slate-100 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
    >
      <h3 class="mb-3 text-sm font-semibold text-slate-700 dark:text-slate-200">
        {{ $t('CAMPAIGN_REPORTS.CHARTS.PER_CAMPAIGN_TABLE') }}
      </h3>
      <div class="overflow-x-auto">
        <table class="w-full text-left text-sm">
          <thead>
            <tr
              class="border-b border-slate-200 text-xs uppercase text-slate-500 dark:border-slate-600 dark:text-slate-400"
            >
              <th
                v-for="col in tableColumns"
                :key="col.key"
                class="cursor-pointer px-3 py-2"
                @click="toggleSort(col.key)"
              >
                {{ col.label }}{{ sortIndicator(col.key) }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in paginatedCampaignList"
              :key="row.id"
              class="border-b border-slate-100 dark:border-slate-700"
            >
              <td class="px-3 py-2 text-slate-800 dark:text-slate-200">
                {{ row.title }}
              </td>
              <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
                {{ row.channel_type }}
              </td>
              <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
                {{ row.succeeded }}
              </td>
              <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
                {{ row.replies }}
              </td>
              <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
                {{ `${row.reply_rate}%` }}
              </td>
            </tr>
            <tr v-if="!sortedCampaignList.length">
              <td
                colspan="5"
                class="px-3 py-4 text-center text-slate-400 dark:text-slate-500"
              >
                {{ $t('CAMPAIGN_REPORTS.NO_DATA') }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div
        v-if="sortedCampaignList.length > pageSize"
        class="mt-3 flex items-center justify-between"
      >
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{
            $t('CAMPAIGN_REPORTS.TABLE.PAGINATION_INFO', {
              from: (currentPage - 1) * pageSize + 1,
              to: Math.min(currentPage * pageSize, sortedCampaignList.length),
              total: sortedCampaignList.length,
            })
          }}
        </span>
        <div class="flex gap-2">
          <button
            :disabled="currentPage <= 1"
            class="rounded-md border border-slate-200 px-3 py-1 text-xs text-slate-600 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-40 dark:border-slate-600 dark:text-slate-300 dark:hover:bg-slate-700"
            @click="currentPage--"
          >
            {{ $t('CAMPAIGN_REPORTS.TABLE.PREV') }}
          </button>
          <button
            :disabled="currentPage >= totalPages"
            class="rounded-md border border-slate-200 px-3 py-1 text-xs text-slate-600 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-40 dark:border-slate-600 dark:text-slate-300 dark:hover:bg-slate-700"
            @click="currentPage++"
          >
            {{ $t('CAMPAIGN_REPORTS.TABLE.NEXT') }}
          </button>
        </div>
      </div>
    </div>

    <!-- Heatmap -->
    <div
      class="rounded-lg border border-slate-100 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
    >
      <h3 class="mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200">
        {{ $t('CAMPAIGN_REPORTS.CHARTS.VOLUME_HEATMAP') }}
      </h3>
      <div class="h-72">
        <BarChart
          :collection="heatmapChartData"
          :chart-options="{
            scales: { x: { stacked: true }, y: { stacked: true } },
          }"
        />
      </div>
    </div>

    <!-- Download buttons -->
    <div class="flex gap-3">
      <button
        class="rounded-lg bg-woot-500 px-4 py-2 text-sm font-medium text-white hover:bg-woot-600"
        @click="downloadCampaignList"
      >
        {{ $t('CAMPAIGN_REPORTS.DOWNLOAD_LIST') }}
      </button>
      <button
        class="rounded-lg bg-slate-100 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-200 dark:bg-slate-700 dark:text-slate-200 dark:hover:bg-slate-600"
        @click="downloadDeliveryDetail"
      >
        {{ $t('CAMPAIGN_REPORTS.DOWNLOAD_DELIVERY') }}
      </button>
    </div>
  </div>
</template>
