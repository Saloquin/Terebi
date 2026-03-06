import React from 'react';

export interface DashboardCard {
  id: string;
  title: string;
  component: React.ComponentType<any>;
  minSize: {
    w: number;
    h: number;
  };
}

export interface DashboardLayout {
  i: string;
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface DashboardConfig {
  cards: DashboardCard[];
  layout: DashboardLayout[];
}

export interface User {
  id: string;
  name: string;
  email: string;
}

export interface NavigationItem {
  id: string;
  label: string;
  path: string;
  icon?: string;
}