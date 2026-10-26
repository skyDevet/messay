export function ProjectModal({ project, onClose, onRequest }) {
  if (!project) return null;
  return (
    <div class="modal-overlay" onClick={onClose}>
      <div class="modal" onClick={e => e.stopPropagation()}>
        <button class="modal-close" onClick={onClose}>âœ•</button>
        <h2>{project.title}</h2>
        <p style="color: var(--gray); font-size: 0.9rem;">{project.desc}</p>
        <div class="modal-meta">
          <span><strong>Type:</strong> {project.type}</span>
          <span><strong>Budget:</strong> {project.budget}</span>
          <span><strong>Duration:</strong> {project.duration}</span>
          <span><strong>Year:</strong> {project.year}</span>
          <span><strong>Client:</strong> {project.client}</span>
        </div>
        <a href="#request-services" onClick={(e) => { e.preventDefault(); onClose(); if (onRequest) onRequest('services'); }} class="btn btn-primary" style="display:block;text-align:center;margin-top:14px;">Request Similar Project</a>
      </div>
    </div>
  );
}
