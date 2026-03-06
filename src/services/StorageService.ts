import { DashboardConfig } from '../types';

class StorageService {
  private static instance: StorageService;
  private readonly DASHBOARD_KEY = 'dashboard_config';

  static getInstance(): StorageService {
    if (!StorageService.instance) {
      StorageService.instance = new StorageService();
    }
    return StorageService.instance;
  }

  saveDashboardConfig(config: DashboardConfig): void {
    try {
      localStorage.setItem(this.DASHBOARD_KEY, JSON.stringify(config));
    } catch (error) {
      console.error('Error saving dashboard config:', error);
    }
  }

  loadDashboardConfig(): DashboardConfig | null {
    try {
      const config = localStorage.getItem(this.DASHBOARD_KEY);
      return config ? JSON.parse(config) : null;
    } catch (error) {
      console.error('Error loading dashboard config:', error);
      return null;
    }
  }

  clearDashboardConfig(): void {
    localStorage.removeItem(this.DASHBOARD_KEY);
  }
}

export default StorageService.getInstance();