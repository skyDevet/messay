import { useStore } from '../data/store.js';
export function Footer() {
  const [data, lang] = useStore();
  const b = data.business;
  return (
    <footer><div class="container">
      <div class="logo" style="font-size:1.4rem;">Mesay <span>Abebe</span></div>
      <div class="license">{b.fieldOfBusiness} Â· License {b.businessLicenseNo} Â· TIN {b.tin}</div>
      <div class="foot-links">
        <a href="#services">{lang === 'am' ? 'áŠ áŒˆáˆáŒáˆŽá‰¶á‰½' : 'Services'}</a>
        <a href="#projects">{lang === 'am' ? 'á•áˆ®áŒ€áŠ­á‰¶á‰½' : 'Projects'}</a>
        <a href="#catalog">{lang === 'am' ? 'á‰áˆ³á‰áˆ¶á‰½' : 'Materials'}</a>
        <a href={'tel:' + b.cell1.replace(/\s/g, '')}>{b.cell1}</a>
        <a href={'mailto:' + b.email}>{b.email}</a>
      </div>
      <p>{b.addressEn}</p>
      <p style="margin-top:4px;font-size:0.76rem;">Issued by {b.bureau} Â· Renewal {b.renewalDate} Â· Capital {b.capital}</p>
      <p style="margin-top:8px;">Â© 2024 {b.nameEn}. All rights reserved.</p>
    </div></footer>
  );
}
