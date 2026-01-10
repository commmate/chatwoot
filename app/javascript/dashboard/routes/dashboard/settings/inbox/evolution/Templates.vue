<script>
import { useAlert } from 'dashboard/composables';
import EvolutionAPI from 'dashboard/api/evolution';
import SettingsSection from 'dashboard/components/SettingsSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import Modal from 'dashboard/components/Modal.vue';

const TEMPLATE_CATEGORIES = ['AUTHENTICATION', 'MARKETING', 'UTILITY'];
const COMPONENT_TYPES = ['HEADER', 'BODY', 'FOOTER', 'BUTTONS'];

export default {
  components: {
    SettingsSection,
    NextButton,
    Spinner,
    Modal,
  },
  props: {
    inbox: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isLoading: true,
      templates: [],
      showCreateModal: false,
      isCreating: false,
      isDeleting: false,
      templateToDelete: null,
      // New template form
      newTemplate: {
        name: '',
        category: 'MARKETING',
        language: 'en',
        allowCategoryChange: true,
        bodyText: '',
      },
    };
  },
  computed: {
    categories() {
      return TEMPLATE_CATEGORIES;
    },
    componentTypes() {
      return COMPONENT_TYPES;
    },
    safeTemplates() {
      // Ensure templates is always an array and filter out null values
      const templateList = Array.isArray(this.templates) ? this.templates : [];
      return templateList.filter(t => t !== null && t !== undefined);
    },
    approvedTemplates() {
      return this.safeTemplates.filter(t => t.status === 'APPROVED');
    },
    pendingTemplates() {
      return this.safeTemplates.filter(t => t.status === 'PENDING');
    },
    rejectedTemplates() {
      return this.safeTemplates.filter(t => t.status === 'REJECTED');
    },
  },
  mounted() {
    this.fetchTemplates();
  },
  methods: {
    async fetchTemplates() {
      this.isLoading = true;
      try {
        const response = await EvolutionAPI.getTemplates(this.inbox.id);
        const templateData = response.data.templates || response.data || [];
        // Ensure templates is always an array
        this.templates = Array.isArray(templateData) ? templateData : [];
      } catch (error) {
        this.templates = []; // Reset to empty array on error
        useAlert(
          error.response?.data?.error ||
            this.$t('INBOX_MGMT.EVOLUTION.TEMPLATES.FETCH_ERROR')
        );
      } finally {
        this.isLoading = false;
      }
    },
    openCreateModal() {
      this.newTemplate = {
        name: '',
        category: 'MARKETING',
        language: 'en',
        allowCategoryChange: true,
        bodyText: '',
      };
      this.showCreateModal = true;
    },
    closeCreateModal() {
      this.showCreateModal = false;
    },
    async createTemplate() {
      if (!this.newTemplate.name || !this.newTemplate.bodyText) {
        useAlert(this.$t('INBOX_MGMT.EVOLUTION.TEMPLATES.VALIDATION_ERROR'));
        return;
      }

      this.isCreating = true;
      try {
        // Build components array
        const components = [
          {
            type: 'BODY',
            text: this.newTemplate.bodyText,
          },
        ];

        await EvolutionAPI.createTemplate(this.inbox.id, {
          name: this.newTemplate.name.toLowerCase().replace(/\s+/g, '_'),
          category: this.newTemplate.category,
          language: this.newTemplate.language,
          allow_category_change: this.newTemplate.allowCategoryChange,
          components,
        });

        useAlert(this.$t('INBOX_MGMT.EVOLUTION.TEMPLATES.CREATE_SUCCESS'));
        this.closeCreateModal();
        this.fetchTemplates();
      } catch (error) {
        const errorMessage =
          error.response?.data?.details?.message ||
          error.response?.data?.error ||
          this.$t('INBOX_MGMT.EVOLUTION.TEMPLATES.CREATE_ERROR');
        useAlert(errorMessage);
      } finally {
        this.isCreating = false;
      }
    },
    confirmDelete(template) {
      this.templateToDelete = template;
    },
    cancelDelete() {
      this.templateToDelete = null;
    },
    async deleteTemplate() {
      if (!this.templateToDelete) return;

      this.isDeleting = true;
      try {
        await EvolutionAPI.deleteTemplate(
          this.inbox.id,
          this.templateToDelete.name
        );
        useAlert(this.$t('INBOX_MGMT.EVOLUTION.TEMPLATES.DELETE_SUCCESS'));
        this.templateToDelete = null;
        this.fetchTemplates();
      } catch (error) {
        useAlert(
          error.response?.data?.error ||
            this.$t('INBOX_MGMT.EVOLUTION.TEMPLATES.DELETE_ERROR')
        );
      } finally {
        this.isDeleting = false;
      }
    },
    getStatusClass(status) {
      switch (status) {
        case 'APPROVED':
          return 'bg-green-100 text-green-800';
        case 'PENDING':
          return 'bg-yellow-100 text-yellow-800';
        case 'REJECTED':
          return 'bg-red-100 text-red-800';
        default:
          return 'bg-gray-100 text-gray-800';
      }
    },
    getCategoryClass(category) {
      switch (category) {
        case 'MARKETING':
          return 'bg-purple-100 text-purple-800';
        case 'UTILITY':
          return 'bg-blue-100 text-blue-800';
        case 'AUTHENTICATION':
          return 'bg-orange-100 text-orange-800';
        default:
          return 'bg-gray-100 text-gray-800';
      }
    },
    getTemplateBody(template) {
      const bodyComponent = template.components?.find(c => c.type === 'BODY');
      return bodyComponent?.text || '';
    },
  },
};
</script>

<template>
  <div class="mx-8">
    <Spinner v-if="isLoading" />

    <template v-else>
      <SettingsSection
        :title="$t('INBOX_MGMT.EVOLUTION.TEMPLATES.TITLE')"
        :sub-title="$t('INBOX_MGMT.EVOLUTION.TEMPLATES.DESCRIPTION')"
        :show-border="false"
      >
        <div class="mb-4">
          <NextButton
            :label="$t('INBOX_MGMT.EVOLUTION.TEMPLATES.CREATE_BUTTON')"
            @click="openCreateModal"
          />
        </div>

        <!-- Templates List -->
        <div v-if="templates.length === 0" class="text-center py-8 text-n-slate-11">
          {{ $t('INBOX_MGMT.EVOLUTION.TEMPLATES.EMPTY') }}
        </div>

        <div v-else class="space-y-4">
          <div
            v-for="template in safeTemplates"
            :key="template.id"
            class="p-4 border border-n-weak rounded-lg"
          >
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="flex items-center gap-2 mb-2">
                  <h3 class="text-base font-medium text-n-slate-12">
                    {{ template.name }}
                  </h3>
                  <span
                    class="px-2 py-0.5 text-xs rounded-full"
                    :class="getStatusClass(template.status)"
                  >
                    {{ template.status }}
                  </span>
                  <span
                    class="px-2 py-0.5 text-xs rounded-full"
                    :class="getCategoryClass(template.category)"
                  >
                    {{ template.category }}
                  </span>
                </div>
                <p class="text-sm text-n-slate-11 mb-2">
                  {{ $t('INBOX_MGMT.EVOLUTION.TEMPLATES.LANGUAGE') }}: {{ template.language }}
                </p>
                <p class="text-sm text-n-slate-12 whitespace-pre-wrap">
                  {{ getTemplateBody(template) }}
                </p>
              </div>
              <NextButton
                ghost
                color-scheme="alert"
                size="sm"
                icon="i-lucide-trash-2"
                :label="$t('INBOX_MGMT.EVOLUTION.TEMPLATES.DELETE_BUTTON')"
                @click="confirmDelete(template)"
              />
            </div>
          </div>
        </div>
      </SettingsSection>
    </template>

    <!-- Create Template Modal -->
    <Modal
      v-model:show="showCreateModal"
      :on-close="closeCreateModal"
      size="medium"
    >
      <div class="p-6">
        <h2 class="text-lg font-medium text-n-slate-12 mb-4">
          {{ $t('INBOX_MGMT.EVOLUTION.TEMPLATES.CREATE_TITLE') }}
        </h2>

        <form @submit.prevent="createTemplate" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-1">
              {{ $t('INBOX_MGMT.EVOLUTION.TEMPLATES.FORM.NAME') }}
            </label>
            <input
              v-model="newTemplate.name"
              type="text"
              class="w-full"
              :placeholder="$t('INBOX_MGMT.EVOLUTION.TEMPLATES.FORM.NAME_PLACEHOLDER')"
            />
            <p class="text-xs text-n-slate-11 mt-1">
              {{ $t('INBOX_MGMT.EVOLUTION.TEMPLATES.FORM.NAME_HELP') }}
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-1">
              {{ $t('INBOX_MGMT.EVOLUTION.TEMPLATES.FORM.CATEGORY') }}
            </label>
            <select v-model="newTemplate.category" class="w-full">
              <option v-for="cat in categories" :key="cat" :value="cat">
                {{ cat }}
              </option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-1">
              {{ $t('INBOX_MGMT.EVOLUTION.TEMPLATES.FORM.LANGUAGE') }}
            </label>
            <select v-model="newTemplate.language" class="w-full">
              <option value="en">English</option>
              <option value="en_US">English (US)</option>
              <option value="pt_BR">Portuguese (Brazil)</option>
              <option value="es">Spanish</option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-1">
              {{ $t('INBOX_MGMT.EVOLUTION.TEMPLATES.FORM.BODY') }}
            </label>
            <textarea
              v-model="newTemplate.bodyText"
              rows="4"
              class="w-full"
              :placeholder="$t('INBOX_MGMT.EVOLUTION.TEMPLATES.FORM.BODY_PLACEHOLDER')"
            />
            <p class="text-xs text-n-slate-11 mt-1">
              {{ $t('INBOX_MGMT.EVOLUTION.TEMPLATES.FORM.BODY_HELP') }}
            </p>
          </div>

          <label class="flex items-center gap-2">
            <input v-model="newTemplate.allowCategoryChange" type="checkbox" />
            <span class="text-sm">{{ $t('INBOX_MGMT.EVOLUTION.TEMPLATES.FORM.ALLOW_CATEGORY_CHANGE') }}</span>
          </label>

          <div class="flex justify-end gap-2 pt-4">
            <NextButton
              ghost
              :label="$t('INBOX_MGMT.EVOLUTION.TEMPLATES.FORM.CANCEL')"
              @click="closeCreateModal"
            />
            <NextButton
              type="submit"
              :is-loading="isCreating"
              :label="$t('INBOX_MGMT.EVOLUTION.TEMPLATES.FORM.SUBMIT')"
            />
          </div>
        </form>
      </div>
    </Modal>

    <!-- Delete Confirmation Modal -->
    <Modal
      v-if="templateToDelete"
      :show="!!templateToDelete"
      :on-close="cancelDelete"
      size="small"
    >
      <div class="p-6">
        <h2 class="text-lg font-medium text-n-slate-12 mb-2">
          {{ $t('INBOX_MGMT.EVOLUTION.TEMPLATES.DELETE_CONFIRM_TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ $t('INBOX_MGMT.EVOLUTION.TEMPLATES.DELETE_CONFIRM_MESSAGE', { name: templateToDelete.name }) }}
        </p>
        <div class="flex justify-end gap-2">
          <NextButton
            ghost
            :label="$t('INBOX_MGMT.EVOLUTION.TEMPLATES.FORM.CANCEL')"
            @click="cancelDelete"
          />
          <NextButton
            color-scheme="alert"
            :is-loading="isDeleting"
            :label="$t('INBOX_MGMT.EVOLUTION.TEMPLATES.DELETE_BUTTON')"
            @click="deleteTemplate"
          />
        </div>
      </div>
    </Modal>
  </div>
</template>

