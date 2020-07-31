package com.spring.tourism.DAO;

import com.spring.tourism.Entity.RaiderCommentEntity;
import org.springframework.lang.NonNull;

import java.util.List;

public interface RaiderCommentDAO {
    List<RaiderCommentEntity> getRaiderCommentEntityByRaiderId(@NonNull String raiderId);

    void insertRaiderCommentEntity(@NonNull RaiderCommentEntity raiderCommentEntity);

    List<RaiderCommentEntity> getRaiderCommentByRaiderIdAndUserId(@NonNull String raiderId,
                                                                  @NonNull String userId);

    void removeRaiderCommentByRaiderIdAndUserIdAndCommentId(@NonNull String raiderId,
                                                            @NonNull String userId,
                                                            @NonNull Integer commentId);
}
