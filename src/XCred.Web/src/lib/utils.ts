import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(date: string | Date): string {
  return new Intl.DateTimeFormat('en-US', { dateStyle: 'medium' }).format(new Date(date));
}

export function formatDateTime(date: string | Date): string {
  return new Intl.DateTimeFormat('en-US', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(date));
}

export function daysUntil(date: string | Date): number {
  const diff = new Date(date).getTime() - Date.now();
  return Math.floor(diff / (1000 * 60 * 60 * 24));
}

export function credentialTypeLabel(type: string): string {
  const labels: Record<string, string> = {
    WebsiteLogin: 'Website Login',
    Database: 'Database',
    ApiKey: 'API Key',
    SshKey: 'SSH Key',
    CreditCard: 'Credit / Debit Card',
    SecureNote: 'Secure Note',
    WiFi: 'Wi-Fi',
    SoftwareLicense: 'Software License',
    Certificate: 'Certificate',
    EnvironmentVariables: 'Environment Variables',
    Generic: 'Generic',
  };
  return labels[type] ?? type;
}

export function credentialTypeIcon(type: string): string {
  const icons: Record<string, string> = {
    WebsiteLogin: '🌐',
    Database: '🗄️',
    ApiKey: '🔑',
    SshKey: '🖥️',
    CreditCard: '💳',
    SecureNote: '📝',
    WiFi: '📶',
    SoftwareLicense: '📦',
    Certificate: '📜',
    EnvironmentVariables: '⚙️',
    Generic: '🔒',
  };
  return icons[type] ?? '🔒';
}
