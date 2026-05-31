import { useState, useEffect } from 'react';
import { X, Copy, RefreshCw, Check } from 'lucide-react';
import { generatePassword, passwordStrength } from '@/lib/crypto';
import { cn } from '@/lib/utils';

interface Props {
  onSelect: (password: string) => void;
  onClose: () => void;
}

export default function PasswordGeneratorModal({ onSelect, onClose }: Props) {
  const [options, setOptions] = useState({ length: 20, uppercase: true, lowercase: true, numbers: true, symbols: true, excludeAmbiguous: false });
  const [generated, setGenerated] = useState('');
  const [copied, setCopied] = useState(false);

  const generate = () => setGenerated(generatePassword(options));

  useEffect(() => { generate(); }, []);
  useEffect(() => { generate(); }, [options]);

  const strength = passwordStrength(generated);

  const copy = async () => {
    await navigator.clipboard.writeText(generated);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const toggle = (key: keyof typeof options) => {
    if (typeof options[key] === 'boolean') {
      setOptions(prev => ({ ...prev, [key]: !prev[key] }));
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
          <h2 className="font-semibold text-slate-900">Password Generator</h2>
          <button onClick={onClose} className="text-slate-400 hover:text-slate-600 transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6 space-y-5">
          {/* Generated password display */}
          <div className="bg-slate-50 rounded-xl p-4 font-mono text-sm break-all text-slate-800 relative min-h-[60px] flex items-center">
            <span className="flex-1 pr-10">{generated}</span>
            <button onClick={copy} className="absolute right-3 top-1/2 -translate-y-1/2 p-1.5 rounded-lg hover:bg-slate-200 transition-colors text-slate-500">
              {copied ? <Check className="w-4 h-4 text-emerald-600" /> : <Copy className="w-4 h-4" />}
            </button>
          </div>

          {/* Strength bar */}
          <div className="space-y-1">
            <div className="flex justify-between text-xs text-slate-500">
              <span>Strength</span>
              <span className="font-medium">{strength.label}</span>
            </div>
            <div className="h-1.5 bg-slate-200 rounded-full overflow-hidden">
              <div className={cn('h-full rounded-full transition-all', strength.color)} style={{ width: `${(strength.score + 1) * 20}%` }} />
            </div>
          </div>

          {/* Length slider */}
          <div>
            <div className="flex justify-between text-sm mb-2">
              <span className="text-slate-700 font-medium">Length</span>
              <span className="font-bold text-indigo-600">{options.length}</span>
            </div>
            <input type="range" min={8} max={128} value={options.length}
              onChange={e => setOptions(prev => ({ ...prev, length: parseInt(e.target.value) }))}
              className="w-full accent-indigo-600" />
          </div>

          {/* Toggles */}
          <div className="grid grid-cols-2 gap-2">
            {([
              ['uppercase', 'Uppercase (A-Z)'],
              ['lowercase', 'Lowercase (a-z)'],
              ['numbers', 'Numbers (0-9)'],
              ['symbols', 'Symbols (!@#…)'],
              ['excludeAmbiguous', 'Exclude ambiguous'],
            ] as const).map(([key, label]) => (
              <label key={key} className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" checked={options[key] as boolean} onChange={() => toggle(key)}
                  className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
                <span className="text-sm text-slate-600">{label}</span>
              </label>
            ))}
          </div>
        </div>

        <div className="flex gap-2 px-6 pb-6">
          <button onClick={generate}
            className="flex items-center gap-2 px-4 py-2 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50 transition-colors">
            <RefreshCw className="w-3.5 h-3.5" /> Regenerate
          </button>
          <button onClick={() => { onSelect(generated); onClose(); }}
            className="flex-1 bg-indigo-600 text-white py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors">
            Use This Password
          </button>
        </div>
      </div>
    </div>
  );
}
