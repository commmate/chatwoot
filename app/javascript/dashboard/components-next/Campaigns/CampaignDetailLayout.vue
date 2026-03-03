<script setup>
import { computed, useSlots } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Breadcrumb from 'dashboard/components-next/breadcrumb/Breadcrumb.vue';

const props = defineProps({
  campaignTitle: { type: String, default: '' },
  channelLabel: { type: String, default: '' },
});

const emit = defineEmits(['goBack']);

const { t } = useI18n();
const slots = useSlots();

const breadcrumbItems = computed(() => {
  const items = [{ label: props.channelLabel, link: '#' }];
  if (props.campaignTitle) {
    items.push({ label: props.campaignTitle });
  }
  return items;
});

const handleBreadcrumbClick = () => emit('goBack');
</script>

<template>
  <section
    class="flex w-full h-full overflow-hidden justify-evenly bg-n-surface-1"
  >
    <div
      class="flex flex-col w-full h-full transition-all duration-300 ltr:2xl:ml-56 rtl:2xl:mr-56"
    >
      <header class="sticky top-0 z-10 px-6 3xl:px-0">
        <div class="w-full mx-auto max-w-[60rem]">
          <div
            class="flex flex-col xs:flex-row items-start xs:items-center justify-between w-full py-7 gap-2"
          >
            <Breadcrumb
              :items="breadcrumbItems"
              @click="handleBreadcrumbClick"
            />
            <Button
              :label="t('CAMPAIGN.DETAIL_PAGE.BACK_TO_LIST')"
              size="sm"
              slate
              @click="emit('goBack')"
            />
          </div>
        </div>
      </header>
      <main class="flex-1 px-6 overflow-y-auto 3xl:px-px">
        <div class="w-full py-4 mx-auto max-w-[60rem]">
          <slot name="default" />
        </div>
      </main>
    </div>

    <div
      v-if="slots.sidebar"
      class="hidden lg:block overflow-y-auto justify-end min-w-52 w-full py-6 max-w-md border-l border-n-weak bg-n-solid-2"
    >
      <slot name="sidebar" />
    </div>
  </section>
</template>
