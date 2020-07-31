package com.spring.tourism.Repository;

import com.spring.tourism.Entity.RaiderCommentEntity;
import com.spring.tourism.Entity.RaiderCommentEntityPK;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface RaiderCommentRepository
        extends CrudRepository<RaiderCommentEntity, RaiderCommentEntityPK> {
    List<RaiderCommentEntity> getRaiderCommentEntitiesByRaiderId(@Param("raiderId") String raiderId);

    List<RaiderCommentEntity> getRaiderCommentEntitiesByRaiderIdAndUserId(@Param("raiderId") String raiderId,
                                                                          @Param("userId") String userId);

    List<RaiderCommentEntity> getRaiderCommentEntitiesByRaiderIdOrderByCommentDate(@Param("raiderId") String raiderId);
}
