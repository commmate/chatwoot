<script setup>
import { computed } from 'vue';
import { Doughnut } from 'vue-chartjs';
import { Chart as ChartJS, ArcElement, Tooltip, Legend } from 'chart.js';

const props = defineProps({
  collection: {
    type: Object,
    default: () => ({}),
  },
  chartOptions: {
    type: Object,
    default: () => ({}),
  },
});

ChartJS.register(ArcElement, Tooltip, Legend);

const fontFamily =
  'Inter,-apple-system,system-ui,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif';

const defaultChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'bottom',
      labels: {
        font: { family: fontFamily },
        padding: 16,
      },
    },
    tooltip: {
      bodyFont: { family: fontFamily },
    },
  },
  animation: {
    duration: 0,
  },
};

const options = computed(() => {
  return { ...defaultChartOptions, ...props.chartOptions };
});
</script>

<template>
  <Doughnut :data="collection" :options="options" />
</template>
