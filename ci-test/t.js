function m(){var r=document.querySelector('.rail'),b=r.getBoundingClientRect(),cs=getComputedStyle(r),p=getComputedStyle(document.getElementById('probe'));
var bt=[].slice.call(r.querySelectorAll('.home-btn,.co,[data-view=chat]')).map(function(e){var x=e.getBoundingClientRect();return Math.round(x.top)+'-'+Math.round(x.bottom)});
document.getElementById('out').textContent='envBottom='+p.paddingBottom+' envTop='+p.paddingTop+'\ninnerH='+innerHeight+' vv='+(window.visualViewport&&Math.round(visualViewport.height))+' docH='+document.documentElement.clientHeight+
'\nrail top='+Math.round(b.top)+' bottom='+Math.round(b.bottom)+' h='+Math.round(b.height)+'\ncss height='+cs.height+' padT='+cs.paddingTop+' padB='+cs.paddingBottom+'\nclientH='+r.clientHeight+' scrollH='+r.scrollHeight+' scrollTop='+r.scrollTop+'\nbuttons top-bottom: '+bt.join(' ')+'\nUA '+navigator.userAgent.slice(0,60);}
setTimeout(m,500);setTimeout(m,3000);
