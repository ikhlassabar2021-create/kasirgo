import { LucideIcon } from 'lucide-react';

interface MetricCardProps {
  title: string;
  value: string | number;
  percentage?: string;
  isPositive?: boolean;
  icon: LucideIcon;
  iconColor: string;
  bgColor: string;
}

export function StarAdminMetricCard({ 
  title, 
  value, 
  percentage, 
  isPositive = true, 
  icon: Icon,
  iconColor,
  bgColor
}: MetricCardProps) {
  return (
    <div className="bg-white rounded-2xl p-4 sm:p-6 card-shadow hover:shadow-md transition-all duration-200 border border-slate-200/80">
      <div className="flex items-center justify-between mb-3 sm:mb-4">
        <div className={`w-10 h-10 sm:w-12 sm:h-12 ${bgColor} rounded-xl flex items-center justify-center shrink-0`}>
          <Icon className={`w-5 h-5 sm:w-6 sm:h-6 ${iconColor}`} />
        </div>
        {percentage && (
          <span className={`px-2.5 py-1 sm:px-3 sm:py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1 ${
            isPositive 
              ? 'bg-emerald-50 text-emerald-600' 
              : 'bg-rose-50 text-rose-600'
          }`}>
            <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              {isPositive ? (
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 10l7-7m0 0l7 7m-7-7v18" />
              ) : (
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 14l-7 7m0 0l-7-7m7 7V3" />
              )}
            </svg>
            {percentage}
          </span>
        )}
      </div>
      
      <p className="text-[11px] sm:text-xs font-medium text-slate-500 mb-1.5">{title}</p>
      <p className="text-2xl sm:text-[2rem] font-bold leading-none text-slate-900">{value}</p>
    </div>
  );
}
