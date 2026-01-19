/**
 * Flow Registry
 *
 * Registers all tour flows with the flow engine.
 * To add a new flow:
 * 1. Create a new file in this directory (e.g., myNewFlow.js)
 * 2. Export the flow definition
 * 3. Import and register it here
 */

import { registerFlow } from '../flowEngine';

import adminOnboardingEvolutionQr from './adminOnboardingEvolutionQr';
import adminOnboardingAddAgents from './adminOnboardingAddAgents';
import adminOnboardingFinish from './adminOnboardingFinish';
import adminFeatures from './adminFeatures';
import agentFeatures from './agentFeatures';
import conversationReplyTour from './conversationReplyTour';

const flows = [
  adminOnboardingEvolutionQr,
  adminOnboardingAddAgents,
  adminOnboardingFinish,
  adminFeatures,
  agentFeatures,
  conversationReplyTour,
];

/**
 * Initialize all flows - call once at app startup
 */
export function initializeFlows() {
  flows.forEach(flow => registerFlow(flow));
}

export {
  adminOnboardingEvolutionQr,
  adminOnboardingAddAgents,
  adminOnboardingFinish,
  adminFeatures,
  agentFeatures,
  conversationReplyTour,
};
